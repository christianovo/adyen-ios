//
// Copyright (c) 2022 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Adyen
#if canImport(AdyenComponents)
    import AdyenComponents
#endif
#if canImport(AdyenActions)
    import AdyenActions
#endif
#if canImport(AdyenCard)
    import AdyenCard
#endif
import AdyenNetworking
import UIKit

/**
 A component that handles the entire flow of payment selection and payment details entry.

 - SeeAlso:
 [Implementation Reference](https://docs.adyen.com/online-payments/ios/drop-in)
 */
public final class DropInComponent: NSObject,
    AnyDropInComponent,
    ActionHandlingComponent {

    private var configuration: Configuration

    internal var paymentInProgress: Bool = false

    internal var selectedPaymentComponent: PaymentComponent?

    /// The payment methods to display.
    public internal(set) var paymentMethods: PaymentMethods
    
    /// The title text on the first page of drop in component.
    public let title: String

    /// :nodoc:
    public var apiContext: APIContext { configuration.apiContext }

    /// :nodoc:
    public let addressViewModelBuilder: AddressViewModelBuilder
    
    /// Initializes the drop in component.
    ///
    /// - Parameters:
    ///   - paymentMethods: The payment methods to display.
    ///   - configuration: The payment method specific configuration.
    ///   - title: Name of the application. To be displayed on a first payment page.
    ///            If no external value provided, the Main Bundle's name would be used.
    ///   - addressViewModelBuilder: The  address viewmodel builder
    public init(paymentMethods: PaymentMethods,
                configuration: Configuration,
                title: String? = nil,
                addressViewModelBuilder: AddressViewModelBuilder) {
        self.title = title ?? Bundle.main.displayName
        self.configuration = configuration
        self.paymentMethods = paymentMethods
        self.addressViewModelBuilder = addressViewModelBuilder
        super.init()
    }

    // MARK: - Delegates

    /// The delegate of the drop in component.
    public weak var delegate: DropInComponentDelegate?

    /// The partial payment flow delegate.
    public weak var partialPaymentDelegate: PartialPaymentDelegate?
    
    /// The stored payment methods delegate.
    public weak var storedPaymentMethodsDelegate: StoredPaymentMethodsDelegate?

    /// The delegate for user activity on card component.
    public weak var cardComponentDelegate: CardComponentDelegate?
    
    // MARK: - Presentable Component Protocol
    
    /// :nodoc:
    public var viewController: UIViewController { navigationController }

    // MARK: - Handling Actions

    /// Handles an action to complete a payment.
    ///
    /// - Parameter action: The action to handle.
    public func handle(_ action: Action) {
        rootComponent.stopLoadingIfNeeded()
        actionComponent.handle(action)
    }

    // MARK: - Handling Partial Payments

    /// :nodoc:
    private lazy var apiClient: APIClientProtocol = {
        let scheduler = SimpleScheduler(maximumCount: 3)
        return APIClient(apiContext: apiContext)
            .retryAPIClient(with: scheduler)
            .retryOnErrorAPIClient()
    }()
    
    internal func reloadComponentManager() {
        componentManager = createComponentManager(componentManager.order,
                                                  componentManager.remainingAmount)
    }

    /// Reloads the DropIn with a partial payment order and a new `PaymentMethods` object.
    ///
    /// - Parameter order: The partial payment order.
    /// - Parameter paymentMethods: The new payment methods.
    /// - Throws: `PartialPaymentError.missingOrderData` in case `order.orderData` is `nil`.
    public func reload(with order: PartialPaymentOrder,
                       _ paymentMethods: PaymentMethods) throws {
        guard let orderData = order.orderData else { throw PartialPaymentError.missingOrderData }
        let request = OrderStatusRequest(orderData: orderData)
        apiClient.perform(request) { [weak self] result in
            self?.handle(result, order)
        }
    }

    private func handle(_ result: Result<OrderStatusResponse, Error>,
                        _ order: PartialPaymentOrder) {
        result.handle(success: {
            self.handle($0, order)
        }, failure: {
            self.delegate?.didFail(with: $0, from: self)
        })
    }

    private func handle(_ response: OrderStatusResponse, _ order: PartialPaymentOrder) {
        guard response.remainingAmount.value > 0 else {
            delegate?.didFail(with: PartialPaymentError.zeroRemainingAmount, from: self)
            return
        }
        paymentMethods.paid = response.paymentMethods ?? []
        componentManager = createComponentManager(order, response.remainingAmount)
        paymentInProgress = false
        showPaymentMethodsList(onCancel: { [weak self] in
            guard let self = self else { return }
            self.partialPaymentDelegate?.cancelOrder(order, component: self)
        })
    }
    
    // MARK: - Private

    private lazy var componentManager = createComponentManager(nil, nil)

    private func createComponentManager(_ order: PartialPaymentOrder?,
                                        _ remainingAmount: Amount?) -> ComponentManager {
        ComponentManager(paymentMethods: paymentMethods,
                         configuration: configuration,
                         partialPaymentEnabled: partialPaymentDelegate != nil,
                         remainingAmount: remainingAmount,
                         order: order,
                         supportsEditingStoredPaymentMethods: storedPaymentMethodsDelegate != nil,
                         presentationDelegate: self,
                         addressViewModelBuilder: addressViewModelBuilder)
    }
    
    internal lazy var rootComponent: PresentableComponent = {
        if configuration.allowPreselectedPaymentView,
           let preselectedComponents = componentManager.storedComponents.first {
            return preselectedPaymentMethodComponent(for: preselectedComponents, onCancel: nil)
        } else if configuration.allowsSkippingPaymentList,
                  let singleRegularComponent = componentManager.singleRegularComponent {
            setNecessaryDelegates(on: singleRegularComponent)
            return singleRegularComponent
        } else {
            return paymentMethodListComponent(onCancel: nil)
        }
    }()
    
    internal lazy var navigationController = DropInNavigationController(
        rootComponent: rootComponent,
        style: configuration.style.navigation,
        cancelHandler: { [weak self] isRoot, component in
            self?.didSelectCancelButton(isRoot: isRoot, component: component)
        }
    )

    private lazy var actionComponent: AdyenActionComponent = {
        let handler = AdyenActionComponent(apiContext: apiContext)
        handler.configuration.style = configuration.style.actionComponent
        handler._isDropIn = true
        handler.delegate = self
        handler.presentationDelegate = self
        handler.configuration.localizationParameters = configuration.localizationParameters
        handler.configuration.threeDS = configuration.actionComponent.threeDS
        return handler
    }()
    
    internal func paymentMethodListComponent(onCancel: (() -> Void)?) -> PaymentMethodListComponent {
        let paymentComponents = componentManager.sections
        let component = PaymentMethodListComponent(apiContext: apiContext,
                                                   components: paymentComponents,
                                                   style: configuration.style.listComponent)
        component.onCancel = onCancel
        component.localizationParameters = configuration.localizationParameters
        component.delegate = self
        component._isDropIn = true
        return component
    }
    
    internal func preselectedPaymentMethodComponent(for paymentComponent: PaymentComponent,
                                                    onCancel: (() -> Void)?) -> PreselectedPaymentMethodComponent {
        let component = PreselectedPaymentMethodComponent(component: paymentComponent,
                                                          title: title,
                                                          style: configuration.style.formComponent,
                                                          listItemStyle: configuration.style.listComponent.listItem)
        component.payment = configuration.payment
        component.localizationParameters = configuration.localizationParameters
        component.delegate = self
        component.onCancel = onCancel
        component._isDropIn = true
        return component
    }
    
    internal func didSelect(_ component: PaymentComponent) {
        setNecessaryDelegates(on: component)
        
        switch component {
        case let component as PresentableComponent:
            navigationController.present(asModal: component)
        case let component as InstantPaymentComponent:
            component.initiatePayment()
        default:
            break
        }
    }
    
    private func didSelectCancelButton(isRoot: Bool, component: PresentableComponent) {
        guard !paymentInProgress || component is Cancellable else { return }

        userDidCancel(component)
        
        if isRoot {
            self.delegate?.didFail(with: ComponentError.cancelled, from: self)
        } else {
            navigationController.popViewController(animated: true)
        }
    }

    internal func userDidCancel(_ component: Component) {
        stopLoading()
        component.cancelIfNeeded()

        if let component = (component as? PaymentComponent) ?? selectedPaymentComponent, paymentInProgress {
            delegate?.didCancel(component: component, from: self)
        }

        paymentInProgress = false
    }

    internal func stopLoading() {
        (rootComponent as? ComponentLoader)?.stopLoading()
        selectedPaymentComponent?.stopLoadingIfNeeded()
    }
    
    private func setNecessaryDelegates(on component: PaymentComponent) {
        selectedPaymentComponent = component
        component.delegate = self
        (component as? CardComponent)?.cardComponentDelegate = cardComponentDelegate
        (component as? PartialPaymentComponent)?.partialPaymentDelegate = partialPaymentDelegate
        (component as? PartialPaymentComponent)?.readyToSubmitComponentDelegate = self
        (component as? PreApplePayComponent)?.presentationDelegate = self
        
        component._isDropIn = true
        component.payment = configuration.payment
    }
}

private extension Bundle {

    // Name of the app - title under the icon.
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

}
