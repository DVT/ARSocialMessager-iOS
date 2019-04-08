import UIKit
import ARKit
import Firebase
import CoreLocation
import FirebaseDatabase

class ViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var addButton: UIButton!
    var container: UIView?
    var loadingView: UIView?
    private var loginLodingIndicator: UIActivityIndicatorView?
    var scene: SCNScene!
    var storageRef: StorageReference!
    var anchor: StorageReference!
    let locationManager: CLLocationManager = CLLocationManager()
    var ref: DatabaseReference!
    
    var anchorsArray: [MessageAnchor] = []
    
    var didSet = false // beacuse location keeps being updated
    var fileName: String = "" {
        didSet {
            if !didSet {
                showLodingIndicator(mustShow: true)
                retrieveWorldMapData()
                didSet = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        configureLighting()
        setScene()
        storageRef = Storage.storage().reference()
        ref = Database.database().reference()
//        print("bucket \(storageRef.bucket)")

        //Location
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        //for location updates -> uncomment to enable
//        locationManager.startUpdatingHeading()  //for angle
//        locationManager.requestLocation()
        
    }
    
    func setScene() {
        scene = SCNScene()
        sceneView.scene = scene
        
        addButton = UIButton()
        addButton.backgroundColor = .black
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = UIFont(name: "Arial", size: 30)
        addButton.frame = CGRect(x: (view.frame.size.width / 2) - 25, y: view.frame.size.height - 195, width: 50, height: 50)
        addButton.layer.masksToBounds = true
        addButton.layer.cornerRadius = addButton.frame.width/2
        
        addButton.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        self.view.addSubview(addButton)
    }
    
    private func showLodingIndicator(mustShow: Bool) {
        
        if mustShow {
            container = UIView()
            container!.frame = self.view.frame
            container!.center = self.view.center
            container!.backgroundColor = UIColor(displayP3Red: 255, green: 255, blue: 255, alpha: 0.7)
            
            loadingView = UIView()
            loadingView!.frame = CGRect(x: 0.0, y: 0.0, width: 80, height: 80)
            loadingView!.center = self.view.center
            loadingView!.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.4)
            loadingView!.clipsToBounds = true
            loadingView!.layer.cornerRadius = 10
            
            loginLodingIndicator = UIActivityIndicatorView()
            loginLodingIndicator!.frame = CGRect(x: 0.0, y: 0.0, width: 40, height: 40)
            
            let frameWidth = loadingView!.frame.size.width
            let frameHeight = loadingView!.frame.size.height
            loginLodingIndicator?.center = CGPoint(x: frameWidth / 2, y: frameHeight / 2)
            loginLodingIndicator?.hidesWhenStopped = true
            loginLodingIndicator?.style = UIActivityIndicatorView.Style.whiteLarge
            loadingView!.addSubview(loginLodingIndicator!)
            container!.addSubview(loadingView!)
            self.view.addSubview(container!)
            loginLodingIndicator?.startAnimating()
        } else {
            container?.isHidden = true
            loadingView?.isHidden = true
            loginLodingIndicator?.stopAnimating()
            loginLodingIndicator = nil
        }
    }
    

    func generateLabelNode (anchor: ARAnchor) -> SCNNode {
        
        for myAnchor in anchorsArray {
            if myAnchor.ID == anchor.identifier {
                TextHelper.message = myAnchor.message
                break
            }
        }
        
        let text = SCNText(string: TextHelper.message, extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 1)
        text.flatness = 0.005
        let textNode = SCNNode(geometry: text)
        
        var fontScale: Float = 0.01
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            fontScale *= planeAnchor.center.z
        } else {
            fontScale *= anchor.transform.translation.z
        }
    
        fontScale = fontScale < 0 ? fontScale * -1 : fontScale
        
        fontScale = fontScale < 1 && fontScale > 0 ? fontScale * 50 : fontScale
        
        textNode.scale = SCNVector3(fontScale, fontScale, fontScale)
        
        let (min, max) = (text.boundingBox.min, text.boundingBox.max)
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        
        let width = (max.x - min.x) * fontScale
        let height = (max.y - min.y) * fontScale
        let plane = SCNPlane(width: CGFloat(width + 0.01), height: CGFloat(height + 0.01))
        let planeNode = SCNNode(geometry: plane)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.8)
        planeNode.geometry?.firstMaterial?.isDoubleSided = true
        planeNode.position = textNode.position
        textNode.eulerAngles = planeNode.eulerAngles
        
        //rotation
        if let currentFrame =  sceneView.session.currentFrame {
            planeNode.transform = SCNMatrix4MakeRotation(currentFrame.camera.eulerAngles.y, 0 , 1, 0)
        } else {
            planeNode.transform = SCNMatrix4MakeRotation(Float(anchor.transform.columns.1.w), 0 , 1, 0)
        }
        
        //translation
        if let planeAnchor = anchor as? ARPlaneAnchor {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, planeAnchor.center.x, 0, planeAnchor.center.z)
        } else {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, anchor.transform.translation.x, 0, anchor.transform.translation.z)
        }
        planeNode.addChildNode(textNode)
        return planeNode
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @IBAction func resetBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        resetTrackingConfiguration()
    }
    
    @IBAction func saveBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        showLodingIndicator(mustShow: true)
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            self.showLodingIndicator(mustShow: false)
            guard let worldMap = worldMap else {
                return self.setLabel(text: "Error getting current world map.")
            }
            
            do {
                self.anchor = self.storageRef.child(self.fileName)
                try self.archive(worldMap: worldMap)
                DispatchQueue.main.async {
                    self.setLabel(text: "World map is saved.")
                }
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func loadBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        let _ = retrieveWorldMapData()
        showLodingIndicator(mustShow: true)
    }
    
    func loadStuff(worldMap: ARWorldMap) {
        resetTrackingConfiguration(with: worldMap)
    }
    
    func resetTrackingConfiguration(with worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical, .horizontal]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
            setLabel(text: "Found saved world map. Move camera to find text")
        } else {
            setLabel(text: "Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
        let childNodes = scene.rootNode.childNodes
        for node in childNodes {
            node.removeFromParentNode()
        }
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap) throws {
        anchor = storageRef.child("\(fileName)")
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        anchor.putData(data)
    }
    
    func retrieveWorldMapData() -> Data? {
        anchor = storageRef.child("\(fileName)")
        do {
            
            self.anchor.getData(maxSize: 2 * 1024 * 1024) { data, error in
                self.showLodingIndicator(mustShow: false)
                print("world map download error: \(error)")
                print("world map download error: \(data)")
                guard let data = data, let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
                    let worldMap: ARWorldMap = unarchievedObject else { self.setLabel(text: "Error: Failed to unarchieve WorldMap")
                        return }
                for anchor in worldMap.anchors {
                    print("LOADED ID: \(anchor.identifier)")
                }
                
                self.ref.child(self.fileName.replacingOccurrences(of: ".", with: "_"))
                    .observeSingleEvent(of: DataEventType.value) { (snapshot) in
                        
                        snapshot.children.forEach({ (child) in
                            let dataSnap = child as! DataSnapshot
                            let c = dataSnap.value as! [String : String]
                            self.anchorsArray.append(MessageAnchor(id: UUID(uuidString:c["anchorID"]!)! , message:c["text"]!))
                        })
                        
                        if self.anchorsArray.count == snapshot.childrenCount {
                            self.loadStuff(worldMap: worldMap)
                        }
                }
              
                print("world map download error: \(error)")
            }
            return nil
        } catch {
            self.setLabel(text: "Error retrieving world map data.")
            return nil
        }
    }
    
    func unarchive(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
            let worldMap: ARWorldMap = unarchievedObject else { return nil }
        return worldMap
    }
    
    @objc func buttonTap() {
        let alert = UIAlertController(title: "Drop a Memory", message: "Enter a message", preferredStyle: .alert)
        
        //2. Add the text field. You can configure it however you need.
        alert.addTextField { (textField) in
            textField.text = ""
        }
        
        // 3. Grab the value from the text field, and print it when the user clicks OK.
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
            TextHelper.message = textField!.text!
            
            guard let hitTestResult = self.sceneView.hitTest(self.addButton.frame.origin, types: [.featurePoint,
                                                                                                  .estimatedHorizontalPlane,
                                                                                                  .estimatedVerticalPlane,
                                                                                                  .existingPlane,
                                                                                                  .existingPlaneUsingExtent,
                                                                                                  .existingPlaneUsingGeometry]).first
                else { return }
            let anchor = ARAnchor(transform: hitTestResult.worldTransform)
            let model = AnchorTextModel(fileName: self.fileName, anchorID: anchor.identifier.uuidString , text: TextHelper.message)
            print("the messgage model is: \(model)")

            self.ref.child(self.fileName.replacingOccurrences(of: ".", with: "_")).childByAutoId().setValue(["fileName": model.fileName,
                "anchorID": model.anchorID,
                "text": model.text])
            self.sceneView.session.add(anchor: anchor)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { [weak alert] (_) in
            //Just does nothing
        }))
        
        let vc = self.view?.window?.rootViewController
        if vc?.presentedViewController == nil {
            vc?.present(alert, animated: true, completion: nil)
        }
    }
}
    
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        let node = generateLabelNode(anchor: anchor)
        DispatchQueue.main.async {
            self.scene.rootNode.addChildNode(node)
        }
    }
    
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

extension UIColor {
    open class var transparentWhite: UIColor {
        return UIColor.white.withAlphaComponent(0.70)
    }
}

