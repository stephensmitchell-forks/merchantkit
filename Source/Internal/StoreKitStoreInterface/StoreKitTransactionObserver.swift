import StoreKit

internal protocol StoreKitTransactionObserverDelegate : AnyObject {
    func storeKitTransactionObserverWillUpdatePurchases(_ observer: StoreKitTransactionObserver)
    func storeKitTransactionObserverDidUpdatePurchases(_ observer: StoreKitTransactionObserver)
    
    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, didFinishRestoringPurchasesWith result: Result<Void, Error>)
    
    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, didPurchaseProductWith identifier: String, completion: @escaping () -> Void)
    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, didFailToPurchaseProductWith identifier: String, error: Error)
    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, didRestorePurchaseForProductWith identifier: String)

    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, purchaseFor source: Purchase.Source) -> Purchase?
    func storeKitTransactionObserver(_ observer: StoreKitTransactionObserver, responseForStoreIntentToCommit purchase: Purchase) -> StoreIntentResponse
}

/// Observes the payment queue for changes and notifies the delegate of significant updates.
internal final class StoreKitTransactionObserver : NSObject, SKPaymentTransactionObserver {
    public weak var delegate: StoreKitTransactionObserverDelegate?
    
    internal override init() {
        super.init()
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        self.delegate?.storeKitTransactionObserverWillUpdatePurchases(self)
        
        for transaction in transactions {            
            switch transaction.transactionState {
                case .purchased:
                    self.completePurchase(for: transaction)
                case .purchasing:
                    break
                case .restored:
                    self.completeRestorePurchase(for: transaction, original: transaction.original!)
                case .failed:
                    self.failPurchase(for: transaction)
                case .deferred:
                    break
                @unknown default:
                    break
            }
        }
        
        self.delegate?.storeKitTransactionObserverDidUpdatePurchases(self)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        let purchase = self.delegate?.storeKitTransactionObserver(self, purchaseFor: .pendingStorePayment(product, payment))
        
        let response = purchase.flatMap { self.delegate?.storeKitTransactionObserver(self, responseForStoreIntentToCommit: $0) } ?? .default
            
        switch response {
            case .automaticallyCommit:
                return true
            case .defer:
                return false
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        self.delegate?.storeKitTransactionObserver(self, didFinishRestoringPurchasesWith: .success)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        self.delegate?.storeKitTransactionObserver(self, didFinishRestoringPurchasesWith: .failure(error))
    }
    
    private func completePurchase(for transaction: SKPaymentTransaction) {
        self.delegate?.storeKitTransactionObserver(self, didPurchaseProductWith: transaction.payment.productIdentifier, completion: {
            SKPaymentQueue.default().finishTransaction(transaction)
        })
    }
    
    private func completeRestorePurchase(for transaction: SKPaymentTransaction, original: SKPaymentTransaction) {
        self.delegate?.storeKitTransactionObserver(self, didRestorePurchaseForProductWith: original.payment.productIdentifier)
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func failPurchase(for transaction: SKPaymentTransaction) {
        self.delegate?.storeKitTransactionObserver(self, didFailToPurchaseProductWith: transaction.payment.productIdentifier, error: transaction.error!)
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}