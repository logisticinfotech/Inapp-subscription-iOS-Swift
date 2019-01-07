import UIKit
import StoreKit

class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,SKProductsRequestDelegate, SKPaymentTransactionObserver
{
    
    @IBOutlet weak var tblData: UITableView!
    @IBOutlet weak var viewTermsAndCondition: UIView!
    @IBOutlet weak var btnAgree: UIButton!
    
    // Receipt Validation Url
    
    #if DEBUG
    let verifyReceiptURL = "https://sandbox.itunes.apple.com/verifyReceipt"
    #else
    let verifyReceiptURL = "https://buy.itunes.apple.com/verifyReceipt"
    #endif
    
    let kInAppProductPurchasedNotification = "InAppProductPurchasedNotification"
    let kInAppPurchaseFailedNotification   = "InAppPurchaseFailedNotification"
    let kInAppProductRestoredNotification  = "InAppProductRestoredNotification"
    let kInAppPurchasingErrorNotification  = "InAppPurchasingErrorNotification"
    
    // These are the Three Types of Subscription Provided by Application
    
    let autoRenewal = "com.autorenewingtest"
 
    
    // Global Variables
    let arr:NSMutableArray = NSMutableArray()
    var productID:String!
    var productsRequest = SKProductsRequest()
    var iapProducts = [SKProduct]()
    var selectedSubScription:Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // fetch Available product when App is launch
        self.fetchAvailableProducts()
        tblData.delegate = self
        tblData.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.viewTermsAndCondition.isHidden = true
        
        // Fetch the Current Subscription to UserDefaults
        
        if UserDefaults.standard.object(forKey: "currentSubscription") != nil
        {
            productID = UserDefaults.standard.object(forKey: "currentSubscription") as! String
        }
    }
    
    // Fetch the Available Products
    
    func fetchAvailableProducts()
    {
        // Put here your IAP Products ID's
        
        let productIdentifiers = NSSet(objects: autoRenewal)
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers as! Set<String>)
        productsRequest.delegate = self
        productsRequest.start()
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if (response.products.count > 0) {
            iapProducts = response.products
            self.arr.removeAllObjects()
            for prod in response.products
            {
                arr.add(prod)
            }
            tblData.reloadData()
        }
    }
    
    // Request For buy the Available Product
    
    func buyProduct(_ product: SKProduct)
    {
        
        // Add the StoreKit Payment Queue for ServerSide
        SKPaymentQueue.default().add(self)
        if SKPaymentQueue.canMakePayments()
        {
            print("Sending the Payment Request to Apple")
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
            productID = product.productIdentifier
        }
        else
        {
            print("cant purchase")
        }
    }
    
    
    func request(_ request: SKRequest, didFailWithError error: Error)
    {
        print(request)
        print(error)
    }
    
    // Tableview methods for display the Available Subscription
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = (arr.object(at: indexPath.row) as! SKProduct).localizedTitle
                if productID == (arr.object(at: indexPath.row) as! SKProduct).productIdentifier
                {
                     cell.accessoryType = .checkmark
                }
                else
                {
                    cell.accessoryType = .none
                }
        
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
            selectedSubScription = indexPath.row
            UIView.animate(withDuration: 2.0)
            {
                self.viewTermsAndCondition.isHidden = false
        }
    }
    
    
    
    // function for details of all the transtion done for spacific Account
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction:AnyObject in transactions {
            if let trans = transaction as? SKPaymentTransaction {
                switch trans.transactionState {
                    
                case .purchased:
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    print("Success")
                    UserDefaults.standard.setValue(productID, forKey: "currentSubscription")
                    self.tblData.reloadData()
                    self.receiptValidation()
                    break
                case .failed:
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    print("Fail")
                    
                    break
                case .restored:
                    print("restored")
                    SKPaymentQueue.default().restoreCompletedTransactions()
                    break
                default:
                    break
                }
            }
            
        }
    }
    
    // function for get the receiptValidation from the server for get  receiptValiation we need to recieptString and shared secret which will provided by Apple and we have pass those in following way to get All the subscription Data
    
    func receiptValidation() {
        
        let receiptFileURL = Bundle.main.appStoreReceiptURL
        let receiptData = try? Data(contentsOf: receiptFileURL!)
        let recieptString = receiptData?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let jsonDict: [String: AnyObject] = ["receipt-data" : recieptString! as AnyObject, "password" : "ee70188badc24b1fa8c78f1ddb4cbb3a" as AnyObject]
        
        do {
            let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: JSONSerialization.WritingOptions.prettyPrinted)
            let storeURL = URL(string: verifyReceiptURL)!
            var storeRequest = URLRequest(url: storeURL)
            storeRequest.httpMethod = "POST"
            storeRequest.httpBody = requestData
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let task = session.dataTask(with: storeRequest, completionHandler: { [weak self] (data, response, error) in
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    print("=======>",jsonResponse)
                    if let date = self?.getExpirationDateFromResponse(jsonResponse as! NSDictionary) {
                        print(date)
                    }
                } catch let parseError {
                    print(parseError)
                }
            })
            task.resume()
        } catch let parseError {
            print(parseError)
        }
    }
    
    func getExpirationDateFromResponse(_ jsonResponse: NSDictionary) -> Date? {
        
        if let receiptInfo: NSArray = jsonResponse["latest_receipt_info"] as? NSArray {
            
            let lastReceipt = receiptInfo.lastObject as! NSDictionary
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
            
            if let expiresDate = lastReceipt["expires_date"] as? String {
                return formatter.date(from: expiresDate)
            }
            
            return nil
        }
        else {
            return nil
        }
    }
    
    @IBAction func onClickAgree(_ sender: Any)
    {
        UIView.animate(withDuration: 2.0) {
            self.viewTermsAndCondition.isHidden = true
        }
        buyProduct(iapProducts[selectedSubScription])
    }
    
    @IBAction func onClickBack(_ sender: Any)
    {
        UIView.animate(withDuration: 2.0) {
            self.viewTermsAndCondition.isHidden = true
        }
    }
    @IBAction func gotoWeb(_ sender: Any)
    {
        let url = URL(string: "http://www.logisticinfotech.com")
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url!)
        }
    }
}

