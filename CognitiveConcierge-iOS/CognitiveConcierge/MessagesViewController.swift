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

import UIKit
import JSQMessagesViewController
//import ConversationV1
import TextToSpeechV1
import SpeechToTextV1
import AVFoundation

class MessagesViewController: JSQMessagesViewController {
    
    @IBOutlet weak var backButton: UIButton!
    private var keepChattingBtn: UIButton!
    private var seeRestaurantsBtn: UIButton!
    private var borderView: UIView!
    private var questionLabel: UILabel!
    private var microphoneImage: UIImage!
    private var microphoneButton: UIButton!
    private var sendButton: UIButton!
    private var displayName: String!
    private var decisionsView : DecisionsView?
    private var decisionsViewBottomSpacingConstraint : NSLayoutConstraint!
    private var defaultDecisionsViewBottomSpacingConstraintConstant : CGFloat!
    var type : String?
    
    //Location
    fileprivate var longitude: String?
    fileprivate var latitude: String?
    
    var viewModel: MessagesViewModel!
    
    // Flag to determine when to show buttons.
    var reachedEndOfConversation = false
    
    private var locationManager:CLLocationManager = CLLocationManager()
    
    // Watson Speech to Text Variables
    private var stt: SpeechToText?
    private var recorder: AVAudioRecorder?
    private var isStreamingDefault = false
    private var stopStreamingDefault: ((Void) -> Void)? = nil
    private var isStreamingCustom = false
    private var stopStreamingCustom: ((Void) -> Void)? = nil
    private var captureSession: AVCaptureSession? = nil
    
    /// Acts as a store for messages sent and received.
    fileprivate var incomingBubble: JSQMessagesBubbleImage = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor.customAzureColor())
    fileprivate var outgoingBubble: JSQMessagesBubbleImage = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor.customPaleGrayColor())
    
    let kBackButtonTitle: String = "BACK"
    fileprivate let kCollectionViewCellHeight: CGFloat = 12.5
    private let kSendText: String = "SEND"
    private let kPlaceholderText: String = "Speak or type a request"
    private let kKeepChattingButtonTitle: String = "Keep Chatting"
    private let kSeeRestaurantsButtonTitle: String = "See Restaurants"
    private let kQuestionLabelText: String = "WHAT WOULD YOU LIKE TO DO?"
    private let kSegueIdentifier: String = "toRestaurants"
    
    private var isKeyboardShowing:Bool = false
    private var keyboardHeight:CGFloat = 0.0
    
    override func viewDidLoad() {
        // Hide the navigation bar upon loading.
        self.navigationController?.isNavigationBarHidden = true
        
        super.viewDidLoad()
        
        //set up location
        setupLocationServices()
        
        type = type ?? "restaurant"
        
        //set up text bubbles for JSQMessages
        setupTextBubbles()
        
        //add microphone image, send button, textfield to toolbar
        customizeContentView()
        
        //Reload collectionview and layout
        self.collectionView?.reloadData()
        self.collectionView?.layoutIfNeeded()
        
        //setup navigation
        setupNavigation()
        
        //instantiate watson Speech to Text
        instantiateSTT()
        
        subscribeToDecisionButtonNotifications()
        
        setupDecisionsView()
        
        self.inputToolbar.contentView.textView.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        Utils.setupLightNavBar(viewController: self, title: Utils.kNavigationBarTitle)
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.navigationBar.isTranslucent = false
        Utils.setNavigationItems(viewController: self, rightButtons: [], leftButtons: [PathIconBarButtonItem(), UIBarButtonItem(customView: backButton)])
        Utils.setupNavigationTitleLabel(viewController: self, title: Utils.kNavigationBarTitle, spacing: 2.9, titleFontSize: 11, color: UIColor.black)
        //setupLocationServices()
        //Subscribe to when keyboard appears and hides
        subscribeToKeyboardNotifications()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController?.navigationBar.shadowImage = nil
        //locationManager.stopUpdatingLocation()
        removeKeyboardNotifications()
    }
    
    @IBAction func didPressBack(_ sender: AnyObject) {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func setupViewModel() {
        viewModel = MessagesViewModel.sharedInstance
        viewModel.messages = []
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        self.microphoneButton.isEnabled = false
        startStreaming()
    }
    
    private func didReleaseMicrophoneButton(sender: UIButton) {
    }
    
    private func customizeContentView() {
        setupMicrophone()
        setupSendButton()
        self.inputToolbar.contentView.backgroundColor = UIColor.white
        self.inputToolbar.contentView.borderColor = UIColor.black
        self.inputToolbar.contentView.textView.borderColor = UIColor.white
        self.inputToolbar.contentView.textView.placeHolder = kPlaceholderText
        self.inputToolbar.contentView.textView.font = UIFont.regularSFNSDisplay(size: 15)
        
        // Create a border around the text field.
        Utils.addBorderToEdge(textView: self.inputToolbar.contentView.textView, edge: UIRectEdge.left, thickness: 2.0, color: UIColor.customBlueGrayColor())
        Utils.addBorderToEdge(textView: self.inputToolbar.contentView.textView, edge: UIRectEdge.right, thickness: 1.0, color: UIColor.customBlueGrayColor())
    }
    
    private func setupNavigation() {
        Utils.setupBackButton(button: backButton, title: kBackButtonTitle, textColor: UIColor.customGrayColor())
        Utils.setupLightNavBar(viewController: self, title: Utils.kNavigationBarTitle)
        Utils.setNavigationItems(viewController: self, rightButtons: [], leftButtons: [UIBarButtonItem(customView: backButton)])
        self.navigationController?.isNavigationBarHidden = false
    }
    
    private func setupTextBubbles() {
        /// Properties defined in JSQMessages
        senderId = User.Hoffman.rawValue
        senderDisplayName = getName(user: User.Hoffman)
        collectionView?.collectionViewLayout.incomingAvatarViewSize = CGSize(width: 28, height:32 )
        collectionView?.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 37, height:37 )
        automaticallyScrollsToMostRecentMessage = true
    }
    
    /** Method to setup location services to determine user's current location. */
    private func setupLocationServices() -> CLLocationManager {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
            // tell users to enable access in settings
        }
        return locationManager
    }
    
    private func instantiateSTT() {
        // identify credentials file
        let bundle = Bundle(for: type(of: self))
        // load credentials file
        guard let credentialsURL = bundle.path(forResource: "CognitiveConcierge", ofType: "plist") else {
            return
        }
        let dict = NSDictionary(contentsOfFile: credentialsURL)
        guard let credentials = dict as? Dictionary<String, String>,
            let user = credentials["SpeechToTextUsername"],
            let password = credentials["SpeechToTextPassword"]
            else {
                return
        }
        
        stt = SpeechToText(username: user, password: password)
    }
    
    private func setupMicrophone() {
        microphoneImage = UIImage(named: "microphone")
        microphoneButton = UIButton(type: UIButtonType.custom)
        microphoneButton.setImage(microphoneImage, for: UIControlState.normal)
        microphoneButton.frame = CGRect(x: 18, y: 683, width: 14.5, height: 22)
        self.inputToolbar.contentView.leftBarButtonItem = microphoneButton
    }
    
    private func startStreaming() {
        var settings = RecognitionSettings(contentType: .opus)
        settings.continuous = false
        settings.interimResults = true
        
        // ensure SpeechToText service is up
        guard let stt = stt else {
            print("SpeechToText not properly set up.")
            return
        }
        let failure = { (error: Error) in print(error) }
        stt.recognizeMicrophone(settings: settings, failure: failure) { results in
            self.inputToolbar.contentView.textView.text = results.bestTranscript
            self.sendButton.isEnabled = true
            stt.stopRecognizeMicrophone()
            self.microphoneButton.isEnabled = true
        }
    }
    
    private func changeCollectionBottomInset(bottom: CGFloat) {
        let collectionViewLayout = collectionView.collectionViewLayout
        collectionViewLayout?.invalidateLayout()
        collectionViewLayout?.sectionInset = UIEdgeInsetsMake(0, 0, bottom, 0)
    }
    
    private func subscribeToKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector:#selector(MessagesViewController.keyboardWillAppear(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(MessagesViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    @objc private func keyboardWillAppear (notification: NSNotification) {
        let keyboardHeightTest = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size.height

        // Push up decisions view frame by the keyboard height amount
        if (isKeyboardShowing == false) {
            isKeyboardShowing = true
            keyboardHeight = ((notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size.height)!
            self.decisionsViewBottomSpacingConstraint.constant = decisionsViewBottomSpacingConstraint.constant - keyboardHeight
            self.view.layoutIfNeeded()
        } else {
            if let keyboardHeightTest = keyboardHeightTest {
                if keyboardHeightTest > keyboardHeight {
                    self.decisionsViewBottomSpacingConstraint.constant += keyboardHeight
                    self.decisionsViewBottomSpacingConstraint.constant -= keyboardHeightTest
                }
            }
        }
        // Push up collection view by decisions view height
        changeCollectionBottomInset(bottom: decisionsView!.frame.height)
    }
    
    @objc private func keyboardWillHide (notification: NSNotification) {
        // Push up decisions view frame by the keyboard height amount
        if (isKeyboardShowing == true) {
            isKeyboardShowing = false;
            self.decisionsViewBottomSpacingConstraint.constant = defaultDecisionsViewBottomSpacingConstraintConstant
            self.view.layoutIfNeeded()
        }
        // Push up collection view by decisions view height
        changeCollectionBottomInset(bottom: decisionsView!.frame.height)
    }
    
    private func hideDecisionsView() {
        decisionsView!.isHidden = true
        self.sendButton.isEnabled = true
    }
    
    fileprivate func showDecisionsView() {
        decisionsView!.isHidden = false
        
    }
    private func setupDecisionsView() {
        decisionsView = DecisionsView.instanceFromNib() 
        
        self.view.addSubview(decisionsView!)
        decisionsView?.translatesAutoresizingMaskIntoConstraints = false
        decisionsView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        decisionsView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        decisionsViewBottomSpacingConstraint = decisionsView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -inputToolbar.frame.height + 5)
        decisionsViewBottomSpacingConstraint.isActive = true
        defaultDecisionsViewBottomSpacingConstraintConstant = decisionsViewBottomSpacingConstraint.constant
        
        decisionsView?.heightAnchor.constraint(equalToConstant: 95).isActive = true
        hideDecisionsView()
    }
    
    private func setupSendButton() {
        sendButton = UIButton(type: UIButtonType.custom)
        sendButton.setTitle(kSendText, for: UIControlState.normal)
        sendButton.setTitleColor(UIColor.customSendButtonColor(), for: UIControlState.normal)
        sendButton.titleLabel?.font = UIFont.boldSFNSDisplay(size: 15)
        sendButton.titleLabel?.addTextSpacing(spacing: 0.5)
        sendButton.frame = CGRect(x: 321.2, y: 634.5, width: 45, height: 17.5)
        self.inputToolbar.contentView.rightBarButtonItem = sendButton
    }
    
    private func subscribeToDecisionButtonNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(MessagesViewController.keepChattingButtonPressed(object:)), name: NSNotification.Name(rawValue: "keepChattingButtonPressed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MessagesViewController.seeRestaurantsButtonPressed(object:)), name: NSNotification.Name(rawValue: "seeRestaurantsButtonPressed"), object: nil)
    }
    
    
    @objc private func keepChattingButtonPressed ( object: AnyObject) {
        hideDecisionsView()
        reachedEndOfConversation = false
    }
    
    @objc private func seeRestaurantsButtonPressed (object: AnyObject) {
        self.performSegue(withIdentifier: kSegueIdentifier, sender: nil)
    }
    
    // MARK: JSQMessagesViewController method overrides
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        viewModel.parseConversationResponse(text: text, date: date, senderId: senderId, senderDisplayName: senderDisplayName) {
            (reachedEndOfConversation, watsonReply) in
            self.reachedEndOfConversation = reachedEndOfConversation
            self.viewModel.synthesizeText(text: watsonReply)
            DispatchQueue.main.async { self.finishSendingMessage(animated: true) }
        }
        let message = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        viewModel.messages.append(message!)
        finishSendingMessage(animated: true)
    }
    
    // MARK: - Navigation
    
    // Pass the key words from watson to restaurants view controller.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let restaurantsVC = segue.destination as? RestaurantViewController {
            restaurantsVC.keyWords = self.viewModel.watsonEntities
            restaurantsVC.timeInput = self.viewModel.timeInput
            restaurantsVC.latitude = self.latitude
            restaurantsVC.longitude = self.longitude
            restaurantsVC.type = self.type
        }
    }
}

// MARK: - JSQMessagesViewController
extension MessagesViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return viewModel.messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        return viewModel.messages[indexPath.item].senderId == self.senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = viewModel.messages[indexPath.item]
        return getAvatar(id: message.senderId)
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        if (indexPath.item % 3 == 0) {
            //show a timestamp for every 3rd message
            let message = viewModel.messages[indexPath.item]
            return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: message.date)
        }
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAt indexPath: IndexPath!) -> CGFloat {
        
        //show a timestamp for every 3rd message
        if indexPath.item % 3 == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        return kCollectionViewCellHeight
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = viewModel.messages[indexPath.item]
        if message.senderId == senderId {
            cell.textView!.textColor = UIColor.black
        } else {
            cell.textView!.textColor = UIColor.white
            if (reachedEndOfConversation && (indexPath.item == (viewModel.messages.count - 1))) {
                /// Add buttons on top of input toolbar.
                showDecisionsView()
            }
        }
        return cell
    }
}

// MARK: - CLLocationManagerDelegate
extension MessagesViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Grab last object to get the most recent updated location and send to backend.
        //let location:CLLocation = locations[locations.count-1] as CLLocation
        let userLocation:CLLocation = locations[0] as CLLocation
        
        longitude = String(userLocation.coordinate.longitude)
        latitude = String (userLocation.coordinate.latitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        print ("Unable to grab location: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways) || (status == .authorizedWhenInUse) {
            manager.startUpdatingLocation()
        }
    }
}
