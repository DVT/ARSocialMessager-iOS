//
//  DetectionViewController.swift
//  Drop-Memory
//
//  Created by Zaheer Moola on 2019/04/04.
//  Copyright © 2019 DVT. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class DetectionViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        //sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/scene.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.detectionObjects = ARReferenceObject.referenceObjects(inGroupNamed: "gallery", bundle: Bundle.main)!
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    @IBAction func switchMode(_ sender: UISwitch) {
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
  
        let node = SCNNode()
        
        if let objectAnchor = anchor as? ARObjectAnchor {
            let plane = SCNPlane(width: CGFloat(objectAnchor.referenceObject.extent.x * 2), height: CGFloat(objectAnchor.referenceObject.extent.y * 1.2))
            plane.cornerRadius = plane.width * 0.125
            
            guard let name = objectAnchor.referenceObject.name else {
                return nil
            }
            
            var displayScene = SKScene()
            if name.contains("IOSGrads") {
                displayScene = SKScene(fileNamed: "IOSGrads")!
                sceneView.scene.rootNode.childNodes.filter({ $0.name == "IOS" }).forEach({ $0.removeFromParentNode() })
                node.name = "IOS"
            } else if name.contains("netGrads") {
                displayScene = SKScene(fileNamed: "netGrads")!
                sceneView.scene.rootNode.childNodes.filter({ $0.name == "Net" }).forEach({ $0.removeFromParentNode() })
                node.name = "Net"
            } else if name.contains("WebGrads") {
                displayScene = SKScene(fileNamed: "WebGrads")!
                sceneView.scene.rootNode.childNodes.filter({ $0.name == "Web" }).forEach({ $0.removeFromParentNode() })
                node.name = "Web"
            } else if name.contains("JavaGrads") {
                displayScene = SKScene(fileNamed: "JavaGrads")!
                sceneView.scene.rootNode.childNodes.filter({ $0.name == "Java" }).forEach({ $0.removeFromParentNode() })
                node.name = "Java"
            } else if name.contains("UxGrads") {
                displayScene = SKScene(fileNamed: "UxGrads")!
                sceneView.scene.rootNode.childNodes.filter({ $0.name == "Ux" }).forEach({ $0.removeFromParentNode() })
                node.name = "Ux"
            } else if name.contains("noodles") {
                displayScene = SKScene(fileNamed: "noodles")!
            }
    
            plane.firstMaterial?.diffuse.contents = displayScene
            plane.firstMaterial?.isDoubleSided = true
            plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.position = SCNVector3Make(objectAnchor.referenceObject.center.x, objectAnchor.referenceObject.center.y + 0.15, objectAnchor.referenceObject.center.z)
            
            
            node.addChildNode(planeNode)
            
        }
        return node
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }

}
