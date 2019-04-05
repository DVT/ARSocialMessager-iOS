
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
    
    var scene: SCNScene!
    var storageRef: StorageReference!
    var anchor: StorageReference!
    let locationManager: CLLocationManager = CLLocationManager()
    var fileName: String = ""
    
    var ref: DatabaseReference!

    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
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
        addButton.setTitle("Add memory", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        
        self.view.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        addButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        addButton.bottomAnchor.constraint(equalTo: label.topAnchor, constant: 0).isActive = true
        
        sceneView.scene = scene
    }

    func generateLabelNode (anchor: ARAnchor) -> SCNNode {
        
        let skScene = SKScene(size: CGSize(width: 50, height: 50))
        skScene.backgroundColor = UIColor.clear
        
        let rectangle = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 50, height: 50), cornerRadius: 5)
        rectangle.fillColor = #colorLiteral(red: 0.807843148708344, green: 0.0274509806185961, blue: 0.333333343267441, alpha: 1.0)
        rectangle.strokeColor = #colorLiteral(red: 0.439215689897537, green: 0.0117647061124444, blue: 0.192156866192818, alpha: 1.0)
        rectangle.lineWidth = 2
        rectangle.alpha = 0.8
        
        let labelNode = SKLabelNode(text: TextHelper.message)
        labelNode.fontSize = 16
        labelNode.color = .black
        labelNode.position = CGPoint(x: rectangle.frame.midX, y: rectangle.frame.midY)
        skScene.addChild(rectangle)
        skScene.addChild(labelNode)
        
        let plane = SCNPlane(width: 0.2, height: 0.2)
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.diffuse.contents = skScene
        plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
        //let node = SCNNode(geometry: plane)
        
        //adding plane to node to add to scene
        let node = SCNNode(geometry: plane)
        let camera = sceneView.session.currentFrame?.camera
        let camX = camera?.transform.translation.x ?? 0.0
        let camY = camera?.transform.translation.y ?? 0.0
        let camZ = camera?.transform.translation.z ?? 0.0
        
        var x: Float = 0.0
        var y: Float = 0.0
        var z: Float = 0.0
        
        x = anchor.transform.translation.x
        y = anchor.transform.translation.y
        z = anchor.transform.translation.z - camZ
        
        node.position = SCNVector3(x: x, y: y, z: z)
        return node
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
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
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
        let _ = retrieveWorldMapData(from: worldMapURL)
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
    
    func retrieveWorldMapData(from url: URL) -> Data? {
        anchor = storageRef.child("\(fileName)")
        do {
            anchor.getData(maxSize: 2 * 1024 * 1024) { data, error in
                  print("world map download error: \(error)")
                  print("world map download error: \(data)")
                guard let data = data, let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
                    let worldMap: ARWorldMap = unarchievedObject else { return }
                self.loadStuff(worldMap: worldMap)
                 print("world map download error: \(error)")
            }
           
            
            
            //let data =  try Data(contentsOf: self.worldMapURL)
            
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
            self.sceneView.session.add(anchor: anchor)
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

