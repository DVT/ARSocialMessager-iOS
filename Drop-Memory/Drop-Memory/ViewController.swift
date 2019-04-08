
//
//  ViewController.swift
//  ARKitWorkingWithWorldMapData
//
//  Created by Macbook on 8/11/18.
//  Copyright © 2018 Jayven Nhan. All rights reserved.
//

import UIKit
import ARKit
import Firebase
import CoreLocation
import FirebaseDatabase

class ViewController: UIViewController {
    
    var addButton: UIButton!
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var container: UIView?
    var loadingView: UIView?
    private var loginLodingIndicator: UIActivityIndicatorView?
    
    var scene: SCNScene!
    var storageRef: StorageReference!
    var anchor: StorageReference!
    let locationManager: CLLocationManager = CLLocationManager()
    //var fileName: String = ""
    
    var ref: DatabaseReference!

    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
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
        //addTapGestureToSceneView()
        setScene()
        storageRef = Storage.storage().reference()
        ref = Database.database().reference()
        print("bucket \(storageRef.bucket)")
      
        //<<
        //Location Delegates
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
//        locationManager.startUpdatingHeading()  //for angle
        //locationManager.requestLocation()
        
    }
    
    func setScene() {
        scene = SCNScene()
        addButton = UIButton()
        
        addButton.backgroundColor = .black
        addButton.setTitle("+", for: .normal)
        //addButton.titleLabel?.font = [UIFont .systemFontSize:20]
        addButton.setTitleColor(.white, for: .normal)
        
        addButton.titleLabel?.font = UIFont(name: "Arial", size: 30)
        
        //let img = UIImage(named: "Button")
        //addButton.setImage(img, for: .normal)
        addButton.frame = CGRect(x: (view.frame.size.width / 2) - 25, y: view.frame.size.height - 195, width: 50, height: 50)
        addButton.layer.masksToBounds = true
        addButton.layer.cornerRadius = addButton.frame.width/2
        
        
        addButton.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        
        self.view.addSubview(addButton)
        //addButton.translatesAutoresizingMaskIntoConstraints = false
        
        //addButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        //addButton.bottomAnchor.constraint(equalTo: label.topAnchor, constant: 0).isActive = true
        
        sceneView.scene = scene
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
        let fontScale: Float = 0.01
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
            planeNode.transform = SCNMatrix4MakeRotation(anchor.transform.columns.1.w, 0 , 1, 0)
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
    
    func generateBoxNode (anchor: ARAnchor) -> SCNNode {
        let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0.0)
        box.firstMaterial!.diffuse.contents = UIColor.red
        var boxNode = SCNNode(geometry: box)
        var x = anchor.transform.columns.3.x + Float.random(in: 0...0.5)
        var y = anchor.transform.columns.3.y + Float.random(in: 0...0.05)
        var z = anchor.transform.columns.3.z - Float.random(in: 10...15)
        boxNode.position = SCNVector3(x: 0, y: 0, z: 0)
        return boxNode
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
                self.anchor = self.storageRef.child(self.fileName) //<<
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
            setLabel(text: "Found saved world map.")
        } else {
            setLabel(text: "Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
        let childNodes = scene.rootNode.childNodes
        for node in childNodes {
            node.removeFromParentNode()
        }
//        addCameraNode()
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap) throws {
        anchor = storageRef.child("\(fileName)")
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        anchor.putData(data)
        //try data.write(to: self.worldMapURL, options: [.atomic])
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
//                            print("the object is this achoID \(c["anchorID"]!)")
//                            print(c["text"])
                            
                            self.anchorsArray.append(MessageAnchor(id: UUID(uuidString:c["anchorID"]!)! , message:c["text"]!))
                        })
                        
                        if self.anchorsArray.count == snapshot.childrenCount {
                            print("equal!!!")
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
            //self.theRest()
            
            guard let hitTestResult = self.sceneView.hitTest(self.addButton.frame.origin, types: [.featurePoint, .estimatedHorizontalPlane, .estimatedVerticalPlane, .existingPlane]).first
                else { return }
            let anchor = ARAnchor(transform: hitTestResult.worldTransform)
            let model = AnchorTextModel(fileName: self.fileName, anchorID: anchor.identifier.uuidString , text: TextHelper.message)
            //let hitVector = SCNMatrix4FromGLKMatrix4(hitTransform)
            //            let vector3 = SCNVector3()
            print("the messgage model is: \(model)")
            
            self.ref.child(self.fileName.replacingOccurrences(of: ".", with: "_")).childByAutoId().setValue(["fileName": model.fileName,
                "anchorID": model.anchorID,
                "text": model.text])
            self.sceneView.session.add(anchor: anchor)
            print("SAVED ID: \(anchor.identifier)")
        }))
        
        let vc = self.view?.window?.rootViewController
        if vc?.presentedViewController == nil {
            vc?.present(alert, animated: true, completion: nil)
        }
    }
    
    
    func theRest() {
        
        guard let sceneView = self.view as? ARSKView else {
            return
        }
        
        // Create anchor using the camera's current position
        if let currentFrame = sceneView.session.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
        }
    }
    
    
    
    
    func searchJSON(json: [String:Any], searchString: String) -> [String] {
        var array: [String] = []
        let jsonKeys = json.keys
        for i in 0..<jsonKeys.count {
            let level1 = json[jsonKeys.index(jsonKeys.startIndex, offsetBy: i)]
            if let level2 = json[level1.key] as? [String:Any] {
                array.append(contentsOf: searchJSON(json: level2, searchString: searchString))
            }
            else if let level2 = json[level1.key] as? [[String:Any]] {
                for i in 0..<level2.count {
                    array.append(contentsOf: searchJSON(json: level2[i], searchString: searchString))
                }
            } else if let value = json[level1.key] as? String {
                array.append(value)
            }
        }
        return array
    }
    
}


extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        if let currentFrame = sceneView.session.currentFrame{
            let node = generateLabelNode(anchor: anchor)
            DispatchQueue.main.async {
                self.scene.rootNode.addChildNode(node)
                //self.cameraNode.removeFromParentNode()
                //            self.addCameraNode()
            }
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

