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
                _ = retrieveWorldMapData()
                didSet = true
            }
        }
    }
    
    @IBAction func switchMode(_ sender: UISwitch) {
        addButton.isHidden = true
        sender.isHidden = true
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
        
        label.isHidden = true
        
    }
    
    func setScene() {
        scene = SCNScene()
        sceneView.scene = scene
        
        addButton = UIButton()
        addButton.backgroundColor = .black
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = UIFont(name: "Arial", size: 30)
        addButton.frame = CGRect(x: (view.frame.size.width / 2) - 25, y: view.frame.size.height - 120, width: 50, height: 50)
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
        
        
        let text = SCNText(string: TextHelper.message, extrusionDepth: 0.05)
        text.font = UIFont(name: "Arial", size: 10)
        text.flatness = 0.005
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        text.containerFrame = CGRect(origin: .zero, size: CGSize(width: 100.0, height: 500.0))
        text.isWrapped = true
        let textNode = SCNNode(geometry: text)
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        
        let fontScale: Float = 0.01
        
        textNode.scale = SCNVector3(fontScale, fontScale, fontScale)
        
        let (min, max) = (text.boundingBox.min, text.boundingBox.max)
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        
        let width = (max.x - min.x) * fontScale
        let height = (max.y - min.y) * fontScale
        let plane = SCNPlane(width: CGFloat(width * 2), height: CGFloat(height + 0.2))
        var planeNode = SCNNode(geometry: plane)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        plane.cornerRadius = plane.width * 0.05
        planeNode.geometry?.firstMaterial?.isDoubleSided = true
        planeNode.position = textNode.position
        textNode.eulerAngles = planeNode.eulerAngles
        
        //rotation
        if let currentFrame =  sceneView.session.currentFrame {
            planeNode.transform = SCNMatrix4MakeRotation(currentFrame.camera.eulerAngles.y, 0 , 1, 0)
        } else {
            planeNode.transform = SCNMatrix4MakeRotation(Float(anchor.transform.columns.3.y), 0 , 1, 0)
        }
        
        //translation
        if let planeAnchor = anchor as? ARPlaneAnchor {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        } else {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, anchor.transform.translation.x, anchor.transform.translation.y, anchor.transform.translation.z)
        }
        
        textNode.transform = SCNMatrix4Translate(textNode.transform, 0.0, 0.0, 0.01)
        
        if TextHelper.message.contains("lollipop") {
            var displayScene = SKScene(fileNamed: "MeetingTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Lollipop Room"
            }
            
            if let desc = displayScene.childNode(withName: "Description") as? SKLabelNode {
                desc.text = "Seats: 6"
            }
            
            if let label = displayScene.childNode(withName: "Time1") as? SKLabelNode {
                label.text = "11:00 - 12:30"
            }
            
            if let label = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                label.text = "James"
            }
            
            if let label = displayScene.childNode(withName: "Time2") as? SKLabelNode {
                label.text = "13:00 - 14:00"
            }
            
            if let label = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                label.text = "Rose"
            }
            
            if let label = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                label.text = "PJ"
            }
            
            if let label = displayScene.childNode(withName: "Time3") as? SKLabelNode {
                label.text = "09:00 - 10:00"
            }
            
            if let image = displayScene.childNode(withName: "Image") as? SKSpriteNode {
                image.texture = SKTexture(imageNamed: "Lollipop_Room")
                
            }
            
            displayScene.backgroundColor = .clear
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("ctrl") {
            
            var displayScene = SKScene(fileNamed: "MeetingTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Ctrl Room"
            }
            
            if let desc = displayScene.childNode(withName: "Description") as? SKLabelNode {
                desc.text = "Seats: 8"
            }
            
            if let label = displayScene.childNode(withName: "Time3") as? SKLabelNode {
                label.text = "08:00 - 09:30"
            }
            
            if let label = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                label.text = "Rose"
            }
            
            if let label = displayScene.childNode(withName: "Time1") as? SKLabelNode {
                label.text = "10:00 - 11:00"
            }
            
            if let label = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                label.text = "PJ"
            }
            
            if let label = displayScene.childNode(withName: "Time2") as? SKLabelNode {
                label.text = "13:00 - 14:00"
            }
            
            if let label = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                label.text = "Ronnie"
            }
            
            if let image = displayScene.childNode(withName: "Image") as? SKSpriteNode {
                image.texture = SKTexture(imageNamed: "Control_Room")
                
            }
            
            displayScene.backgroundColor = .clear
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("alt") {
            var displayScene = SKScene(fileNamed: "MeetingTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Alt Room"
            }
            
            if let desc = displayScene.childNode(withName: "Description") as? SKLabelNode {
                desc.text = "Seats: 4"
            }
            
            if let label = displayScene.childNode(withName: "Time3") as? SKLabelNode {
                label.text = "07:00 - 08:00"
            }
            
            if let label = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                label.text = "Ronnie"
            }
            
            if let label = displayScene.childNode(withName: "Time1") as? SKLabelNode {
                label.text = "08:00 - 10:00"
            }
            
            if let label = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                label.text = "Theunis"
            }
            
            if let label = displayScene.childNode(withName: "Time2") as? SKLabelNode {
                label.text = "11:00 - 12:00"
            }
            
            if let label = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                label.text = "Saurabh"
            }
            
            if let image = displayScene.childNode(withName: "Image") as? SKSpriteNode {
                image.texture = SKTexture(imageNamed: "Alt_Room")
                
            }
            
            displayScene.backgroundColor = .clear
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("del") {
            var displayScene = SKScene(fileNamed: "MeetingTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Del Room"
            }
            
            if let desc = displayScene.childNode(withName: "Description") as? SKLabelNode {
                desc.text = "Seats: 4"
            }
            
            if let label = displayScene.childNode(withName: "Time1") as? SKLabelNode {
                label.text = "09:00 - 10:30"
            }
            
            if let label = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                label.text = "Ike"
            }
            
            if let label = displayScene.childNode(withName: "Time2") as? SKLabelNode {
                label.text = "15:00 - 16:00"
            }
            
            if let label = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                label.text = "Chris"
            }
            
            if let label = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                label.text = "James"
            }
            
            if let label = displayScene.childNode(withName: "Time3") as? SKLabelNode {
                label.text = "07:00 - 07:30"
            }
            
            if let image = displayScene.childNode(withName: "Image") as? SKSpriteNode {
                image.texture = SKTexture(imageNamed: "Delete_Room")
                
            }
            
            displayScene.backgroundColor = .clear
            
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("aircon") {
            var displayScene = SKScene(fileNamed: "InfoTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Aircon Remote"
            }
            
            if let info = displayScene.childNode(withName: "Info") as? SKLabelNode {
                info.text = "- Should not be set below 25 \n- Switch off after 6pm \n \n"
            }
            
            if let setter = displayScene.childNode(withName: "Setter") as? SKLabelNode {
                setter.text = "By: Management"
            }
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
            
        } else if TextHelper.message.contains("vending") {
            var displayScene = SKScene(fileNamed: "InfoTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Vending Machine"
            }
            
            if let info = displayScene.childNode(withName: "Info") as? SKLabelNode {
                info.preferredMaxLayoutWidth = 350
                info.text = "- For assistance with the vending machine contact Bongani \n- Only accepts R10 and R20 notes"
                
            }
            
            if let setter = displayScene.childNode(withName: "Setter") as? SKLabelNode {
                setter.text = "By: Management"
            }
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
            
        } else if TextHelper.message.contains("aid") {
            var displayScene = SKScene(fileNamed: "InfoTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "First Aid Kit"
            }
            
            if let info = displayScene.childNode(withName: "Info") as? SKLabelNode {
                info.text = "- Contact James if you're dying ☠️ and need the key \n 😷"
                info.preferredMaxLayoutWidth = 350
            }
            
            if let setter = displayScene.childNode(withName: "Setter") as? SKLabelNode {
                setter.text = "By: Management"
            }
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("hangers") {
            var displayScene = SKScene(fileNamed: "InfoTemplate")!
            
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Alien Contact \nDevice"
            }
            
            if let info = displayScene.childNode(withName: "Info") as? SKLabelNode {
                info.text = "- Pull these buttons to call the 👽 aliens 👽 \n \n"
                info.preferredMaxLayoutWidth = 350
            }
            
            if let setter = displayScene.childNode(withName: "Setter") as? SKLabelNode {
                setter.text = "By: James"
            }
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
            planeNode.addChildNode(node)
        } else if TextHelper.message.contains("office1") {
            var displayScene = SKScene(fileNamed: "OfficeTemplate")!
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "HR Office"
            }
            
            if let image = displayScene.childNode(withName: "Image1") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Jon")!.circleMasked! )
            }
            if let setter = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                setter.text = "Jon"
            }
            
            if let image = displayScene.childNode(withName: "Image2") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Daenerys")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                name.text = "Daenerys"
            }
            
            if let image = displayScene.childNode(withName: "Image3") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Jaime")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                name.text = "Jaime"
            }
            
            if let image = displayScene.childNode(withName: "Image4") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Tyrion")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name4") as? SKLabelNode {
                name.text = "Tyrion"
            }
            
            if let image = displayScene.childNode(withName: "Image5") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Bronn")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name5") as? SKLabelNode {
                name.text = "Bronn"
            }
            
            if let image = displayScene.childNode(withName: "Image6") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "Cersei")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name6") as? SKLabelNode {
                name.text = "Cersei"
            }
            
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
        } else if TextHelper.message.contains("office2") {
            var displayScene = SKScene(fileNamed: "OfficeTemplate")!
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = "Admin Office"
            }
            
            if let image = displayScene.childNode(withName: "Image1") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "rdj")!.circleMasked! )
            }
            if let setter = displayScene.childNode(withName: "Name1") as? SKLabelNode {
                setter.text = "Tony"
            }
            
            if let image = displayScene.childNode(withName: "Image2") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "captainAmerica")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name2") as? SKLabelNode {
                name.text = "Steve"
            }
            
            if let image = displayScene.childNode(withName: "Image3") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "thor")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name3") as? SKLabelNode {
                name.text = "Thor"
            }
            
            if let image = displayScene.childNode(withName: "Image4") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "widow")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name4") as? SKLabelNode {
                name.text = "Natasha"
            }
            
            if let image = displayScene.childNode(withName: "Image5") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "spiderman")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name5") as? SKLabelNode {
                name.text = "Peter"
            }
            
            if let image = displayScene.childNode(withName: "Image6") as? SKSpriteNode {
                image.texture = SKTexture( image: UIImage(named: "hulk")!.circleMasked! )
            }
            if let name = displayScene.childNode(withName: "Name6") as? SKLabelNode {
                name.text = "Bruce"
            }
            
            
            displayScene.backgroundColor = UIColor.transparentWhite
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.diffuse.contents = displayScene
            //material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,-1,1)
            plane.materials = [material]
            
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            let node = SCNNode(geometry: plane)
            
        } else {
            planeNode.addChildNode(textNode)
        }
        
        //planeNode.position = SCNVector3(0,0,-0.3)
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
        
        //sceneView.debugOptions = [.showFeaturePoints]
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
                    let worldMap: ARWorldMap = unarchievedObject else { self.setLabel(text: "Error: Failed to unarchive WorldMap")
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

extension UIImage {
    
    var isPortrait:  Bool    { return size.height > size.width }
    var isLandscape: Bool    { return size.width > size.height }
    var breadth:     CGFloat { return min(size.width, size.height) }
    var breadthSize: CGSize  { return CGSize(width: breadth, height: breadth) }
    var breadthRect: CGRect  { return CGRect(origin: .zero, size: breadthSize) }
    
    var circleMasked: UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(breadthSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let cgImage = cgImage?.cropping(to: CGRect(origin:
            CGPoint(
                x: isLandscape ? floor((size.width - size.height) / 2) : 0,
                y: isPortrait  ? floor((size.height - size.width) / 2) : 0),
                                                         size: breadthSize))
            else { return nil }
        
        UIBezierPath(ovalIn: breadthRect).addClip()
        UIImage(cgImage: cgImage, scale: 1, orientation: imageOrientation)
            .draw(in: breadthRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

