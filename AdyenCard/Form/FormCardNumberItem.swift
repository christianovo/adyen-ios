//
// Copyright (c) 2020 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

/// A form item into which a card number is entered.
internal final class FormCardNumberItem: FormTextItem {
    
    private static let binLength = 6
    
    private var previouslyDetectedCardTypes: Set<CardType>?
    
    /// The supported card types.
    internal let supportedCardTypes: [CardType]
    
    /// The card type logos displayed in the form item.
    internal let cardTypeLogos: [CardTypeLogo]
    
    /// The observable of the card's BIN value.
    /// The value contains up to 6 first digits of card' PAN.
    @Observable("") internal var binValue: String
    
    /// The observable of the matching card types for entered PAN.
    /// The value is `nil` when no value entered; empty array when PAN unrecognized or not supported.
    @Observable(nil) internal var detectedCardTypes: [CardType]?
    
    /// :nodoc:
    private let localizationParameters: LocalizationParameters?
    
    /// Initializes the form card number item.
    internal init(supportedCardTypes: [CardType],
                  environment: Environment,
                  style: FormTextItemStyle = FormTextItemStyle(),
                  localizationParameters: LocalizationParameters? = nil) {
        self.supportedCardTypes = supportedCardTypes
        
        let logoURLs = supportedCardTypes.map { LogoURLProvider.logoURL(withName: $0.rawValue, environment: environment) }
        self.cardTypeLogos = logoURLs.map(CardTypeLogo.init)
        self.localizationParameters = localizationParameters
        
        self.style = style
        
        title = ADYLocalizedString("adyen.card.numberItem.title", localizationParameters)
        validator = CardNumberValidator()
        formatter = cardNumberFormatter
        placeholder = ADYLocalizedString("adyen.card.numberItem.placeholder", localizationParameters)
        validationFailureMessage = ADYLocalizedString("adyen.card.numberItem.invalid", localizationParameters)
        keyboardType = .numberPad
    }
    
    // MARK: - Value
    
    internal func valueDidChange() {
        binValue = String(value.prefix(FormCardNumberItem.binLength))
        
        defer {
            previouslyDetectedCardTypes = Set<CardType>(detectedCardTypes ?? [])
        }
        
        func setLogos(for detectedCards: Set<CardType>) {
            for (cardType, logo) in zip(supportedCardTypes, cardTypeLogos) {
                let isVisible = detectedCards.contains(cardType)
                logo.isHidden = !isVisible
            }
        }
        
        guard !value.isEmpty else {
            cardNumberFormatter.cardType = nil
            detectedCardTypes = nil
            setLogos(for: Set<CardType>(supportedCardTypes))
            return
        }
        
        let newDetectedCardTypes = Set<CardType>(cardTypeDetector.types(forCardNumber: value))
        guard previouslyDetectedCardTypes != newDetectedCardTypes else { return }
        
        cardNumberFormatter.cardType = newDetectedCardTypes.first
        setLogos(for: newDetectedCardTypes.isEmpty ? [] : newDetectedCardTypes)
        detectedCardTypes = newDetectedCardTypes.map { $0 }
    }
    
    // MARK: - BuildableFormItem
    
    internal func build(with builder: FormItemViewBuilder) -> AnyFormItemView {
        builder.build(with: self)
    }
    
    // MARK: - Private
    
    private let cardNumberFormatter = CardNumberFormatter()
    
    private lazy var cardTypeDetector: CardTypeDetector = CardTypeDetector(detectableTypes: self.supportedCardTypes)
    
}

extension FormCardNumberItem {
    
    /// Describes a card type logo shown in the card number form item.
    internal final class CardTypeLogo {
        
        /// The URL of the card type logo.
        internal let url: URL
        
        /// Indicates if the card type logo should be hidden.
        @Observable(false) internal var isHidden: Bool
        
        /// Initializes the card type logo.
        ///
        /// - Parameter cardType: The card type for which to initialize the logo.
        internal init(url: URL) {
            self.url = url
        }
        
    }
    
}

extension FormItemViewBuilder {
    internal func build(with item: FormCardNumberItem) -> FormItemView<FormCardNumberItem> {
        FormCardNumberItemView(item: item)
    }
}
