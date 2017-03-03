/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import UIKit
import GooglePlaces
import BMSCore
import BMSAnalytics
import CoreLocation

class RestaurantViewController: UIViewController, CLLocationManagerDelegate  {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var backButton: UIButton!
    
    var theRestaurants: [Restaurant] = []
    var chosenRestaurant: Restaurant?
    var keyWords = [String: String]()
    var timeInput: String?
    var locationManager: CLLocationManager!
    var type : String?
    
    fileprivate var occasion: String?
    var longitude: String?
    var latitude: String?
    private var loadingView : HorizontalOnePartStackView?
    fileprivate var onePartStackView : HorizontalOnePartStackView?
    private var mySubview : UIView?
    fileprivate var watsonOverlay: WatsonOverlay?
    let logger = Logger.logger(name: "My Logger")
    
    
    //// Endpoint manager to make API calls.
    private let endpointManager = EndpointManager.sharedInstance
    private var kNavigationBarTitle = "Places"
    private let kBackButtonTitle = "CHAT"
    fileprivate var kLocationText = "LAS VEGAS, NV"
    fileprivate let kHeightForHeaderInSection:CGFloat = 10
    fileprivate let kEstimatedHeightForRowAtIndexPath:CGFloat = 104.0
    fileprivate let kNumberOfRowsInTableViewSection = 1
    
    override func viewDidLoad() {
        logger.info(message: "App Just loaded")
        super.viewDidLoad()
        loadKeyWords()
        Pluralize()
        
       /* locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()*/
        
        
        self.onePartStackView = HorizontalOnePartStackView.instanceFromNib()
        self.setupStackView(isLoading: true)
        getRestaurantRecommendations(occasion: self.occasion!,type:self.type!, longitude: self.longitude!, latitude: self.latitude!)
        
        // Set up the navigation bar
        Utils.setupDarkNavBar(viewController: self, title: kNavigationBarTitle )
        
        // set up navigation items.
        Utils.setNavigationItems(viewController: self, rightButtons: [MoreIconBarButtonItem()], leftButtons: [WhitePathIconBarButtonItem(), UIBarButtonItem(customView: backButton)])
        
        self.navigationController?.isNavigationBarHidden = false
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        logger.info(message: "View Just Appeared")
        Utils.setupDarkNavBar(viewController: self, title: kNavigationBarTitle)
        self.navigationController?.isNavigationBarHidden = false
        Utils.setupBackButton(button: backButton, title: kBackButtonTitle, textColor: UIColor.white)
        
        // set up navigation items.
        Utils.setNavigationItems(viewController: self, rightButtons: [MoreIconBarButtonItem()], leftButtons: [WhitePathIconBarButtonItem(), UIBarButtonItem(customView: backButton)])
        
        Utils.setupNavigationTitleLabel(viewController: self, title: kNavigationBarTitle, spacing: 1.0, titleFontSize: 17, color: UIColor.white)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.isNavigationBarHidden = true
    }
    
    /** call to Restaurant API to receive recommendations.
     - parameter occasion: user defined setting to look up
     */
    func getRestaurantRecommendations(occasion: String,type: String, longitude:String,latitude:String) {
        logger.info(message: "Looking for restaurants")
        
        //CHANGED
        endpointManager.requestRecommendations(
            endpoint: occasion,
            type: type,
            longitude: longitude,
            latitude: latitude,
            failure: { mockData in
                self.theRestaurants = mockData
                self.setUpTableView()
                self.setupStackView(isLoading: false)
        },
            success: { recommendations in
                self.theRestaurants = Utils.parseRecommendationsJSON(recommendations: recommendations as! [[String : Any]])
                self.setUpTableView()
                self.setupStackView(isLoading: false)
        }
        )
    }
    
    /**
     Method to setup the table view
     */
    func setUpTableView(){
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        guard let configurationPath = Bundle.main.path(forResource: "CognitiveConcierge", ofType: "plist") else {
            print("problem loading configuration file CognitiveConcierge.plist")
            return
        }
        let configuration = NSDictionary(contentsOfFile: configurationPath)
        GMSPlacesClient.provideAPIKey(configuration?["googlePlacesAPIKey"] as! String)
        
        
        registerNibWithTableView(identifier: "restaurant", nibName: "RecommendedRestaurantTableViewCell", tableView: self.tableView)
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = kEstimatedHeightForRowAtIndexPath
        
        tableView.estimatedSectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 9
        tableView.sectionFooterHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
    }
    
    @IBAction func didPressBackButton(_ sender: AnyObject) {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    /**
     Method registers a nib defined by the identifier String parameter and the nibName String parameter with the tableVIew parameter
     
     - parameter identifier: String
     - parameter nibName:    String
     - parameter tableView:  UITableView
     */
    func registerNibWithTableView(identifier: String, nibName: String, tableView: UITableView){
        tableView.register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: identifier)
    }
    
    // MARK - Navigation
    // Pass the key words from watson to restaurants view controller.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let recommendationsVC = segue.destination as? RestaurantDetailViewController {
            if let restaurant = chosenRestaurant {
                recommendationsVC.chosenRestaurant = restaurant
                recommendationsVC.backButtonTitle = kNavigationBarTitle
            } else {
                print("no chosen restaurant found in restaurant VC")
            }
        }
    }
    
    func Pluralize()
    {
        switch(type!)
        {
          case "restaurant":
            kNavigationBarTitle = "RESTAURANTS"
            break
          
          case "spa":
            kNavigationBarTitle = "SPAS"
            break
            
        case "casino":
            kNavigationBarTitle = "CASINOS"
            break
            
            
        default:
            kNavigationBarTitle = "PLACES"
            break


        }
    }
    
    /*func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        
        //manager.stopUpdatingLocation()
        //longitude = String(userLocation.coordinate.longitude)
        //latitude = String (userLocation.coordinate.latitude)
        
        print("user latitude = \(userLocation.coordinate.latitude)")
        print("user longitude = \(userLocation.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }*/
}

/**
 
 MARK: UITableViewDelegate
 
 */
extension RestaurantViewController: UITableViewDelegate {
    
    /**
     Method that defines the action that is taken when a cell of the table view is  selected, in this case we segue to the recommendation detail view controller if the cell selected is at indexPath.row 0
     
     - parameter tableView: UITableView
     - parameter indexPath: NSIndexPath
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        chosenRestaurant = self.theRestaurants[indexPath.section]
        performSegue(withIdentifier: "toRecommendationDetail", sender: self)
    }
    
    /**
     Method that sets up the cell right before its about to be displayed. In this case we remove the 15 pt separator inset
     
     - parameter tableView: UITableView
     - parameter cell:      UITableViewCell
     - parameter indexPath: NSIndexPath
     */
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        //remove 15 pt separator inset so it goes all the way across width of tableview
        tableView.separatorInset = .zero
        tableView.layoutMargins = .zero
        tableView.preservesSuperviewLayoutMargins = false
        
        UIView.performWithoutAnimation { () -> Void in
            cell.layoutIfNeeded()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return kEstimatedHeightForRowAtIndexPath
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return kHeightForHeaderInSection
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.customPaleGrayColor()
        return headerView
    }
}

/**
 
 MARK: UITableViewDataSource
 
 */
extension RestaurantViewController: UITableViewDataSource {
    
    /**
     Method that returns the number of section in the table view by asking the view model
     
     - parameter tableView: UITableView
     
     - returns: Int
     */
    func numberOfSections(in tableView: UITableView) -> Int {
        return theRestaurants.count
    }
    
    
    /**
     Method that returns the number of rows in the section by asking the view model
     
     - parameter tableView: UITableView
     - parameter section:   Int
     
     - returns: Int
     */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return kNumberOfRowsInTableViewSection
    }
    
    
    /**
     Method that returns the cell for row at indexPath by asking the view model to set up th cell
     
     - parameter tableView: UITableView
     - parameter indexPath: NSIndexPath
     
     - returns: UITableViewCell
     */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return setUpTableViewCell(indexPath: indexPath, tableView: tableView)
    }
    
}

extension RestaurantViewController {
    
    /**
     Method that sets up the tableViewCell at the indexPath parameter depending on the type of recommendation type the recommendation is at indexPath
     
     - parameter indexPath: NSIndexPath
     - parameter tableView: UITableView
     
     - returns: UITableViewCell
     */
    func setUpTableViewCell(indexPath: IndexPath, tableView: UITableView) -> UITableViewCell{
        let myRestaurant = self.theRestaurants[indexPath.section]
        var cell : UITableViewCell = UITableViewCell()
        cell = setupRestaurantRecommendationTableViewCell(indexPath: indexPath, tableView: tableView, restaurant: myRestaurant)
        return cell
    }
    
    /**
     Method sets up the tableViewCell at indexPath as a RecommendedRestaurantTableViewCell
     
     - parameter indexPath:      NSIndexPath
     - parameter tableView:      UITableView
     - parameter recommendation: Event
     
     - returns: UITableViewCell
     */
    func setupRestaurantRecommendationTableViewCell(indexPath : IndexPath, tableView : UITableView, restaurant : Restaurant) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "restaurant", for: indexPath) as! RecommendedRestaurantTableViewCell
        
        cell.setUpData(
            restaurantTitle: restaurant.getName(),
            openNowStatus: restaurant.getOpenNowStatus(),
            matchScorePercentage : restaurant.getMatchPercentage(),
            rating: restaurant.getRating(),
            expensiveness: restaurant.getExpense(),
            googleID: restaurant.getGoogleID(),
            image: restaurant.getImage()
        )
        
        return cell
    }
    
    func locationFromLongitudeLatitude(){
    
        let location = CLLocation(latitude: Double(latitude!)!, longitude: Double(longitude!)!);
        print(location)
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
            print(location)
            
            if error != nil {
                print("Reverse geocoder failed with error" + (error?.localizedDescription)!)
                return
            }
            
            if (placemarks?.count)! > 0 {
                let pm = placemarks?[0] as CLPlacemark!
                 self.displayLocationInfo(placemark: pm)
                //locationName = (pm?.locality)!
                print("Locality:" + (pm?.locality)! )
            }
            else {
                print("Problem with the data received from geocoder")
            }
            
        })
       
        
    }
    
    func displayLocationInfo(placemark: CLPlacemark?) {
        if let containsPlacemark = placemark
        {
            //stop updating location to save battery life
            //locationManager.stopUpdatingLocation()
            print((containsPlacemark.locality != nil) ? containsPlacemark.locality! : "")
            print((containsPlacemark.postalCode != nil) ? containsPlacemark.postalCode! : "")
            //print((placemark.administrativeArea != nil) ? placemark.administrativeArea! : "")
            print((containsPlacemark.country != nil) ? containsPlacemark.country! : "")
            
            kLocationText = containsPlacemark.locality! + "," + containsPlacemark.country!
        }
    }

    
    func setupStackView(isLoading:Bool) {
        locationFromLongitudeLatitude()

        if(isLoading) {
            setupLoadingWatsonView()
            
        } else {
            guard let stackView = onePartStackView else {
                return
            }
                        let occasionInput = occasion ?? ""
            let time = timeInput ?? ""
            stackView.setUpData(occasion: occasionInput.uppercased(), location: kLocationText.uppercased(), time: time.uppercased())
            stackView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: bannerView.frame.height)
            bannerView.addSubview(stackView)
            doneLoading()
        }
    }
    
    
    func setupLoadingWatsonView() {
        watsonOverlay = WatsonOverlay.instanceFromNib(view: self.view)
        guard let overlay = watsonOverlay else {
            return
        }
        overlay.showWatsonOverlay(view: self.view)
    }
    
    func doneLoading () {
        guard let watson = watsonOverlay else {
            return
        }
        watson.hideWatsonOverlay()
    }
    
    /* Load key words received from Watson Conversation services in the MessagesViewController.
     * Currently looks only for "occasions" and "time".
     */
    func loadKeyWords() {
        occasion = keyWords["occasions"] ?? "None"
        timeInput = timeInput ?? "Any Time"
        longitude = longitude ?? "-115.17"
        latitude = latitude ?? "36.11"
        type = type ?? "restaurant"
    }
}
