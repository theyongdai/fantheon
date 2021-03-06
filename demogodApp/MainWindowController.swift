//
//  MainWindowController.swift
//
//

import Foundation
import AppKit

class MainWindowController: NSWindowController {
    
    
    //MARK:- private properties
    //MARK:
    fileprivate lazy var theViewController: ViewController = {
        let vc = self.contentViewController as! ViewController
        return vc
    }()
    
    let workQueue = DispatchQueue(label: "com.downloadthebear.MainWindowsC.workq")
    
    var serverConfig = RequestServerContext()
    
    @IBOutlet weak var portNumber: NSTextField?
    @IBOutlet weak var toolbarCommand: NSTextField?
    
    //MARK:- Private functions
    //MARK: 
    fileprivate func startSequence() {
        requestWorkingFolder { [weak self] (url) in
            guard let strongSelf = self else {
                return }
            var startCmd = CliCmd.server(.run(nil))
            if let port = strongSelf.portNumber?.integerValue, port > 1024 {
                startCmd = CliCmd.server(.run(CLIRequestServerContext(port: port)))
            }
            
            strongSelf.serverConfig.storeUrl = (url ?? strongSelf.serverConfig.storeUrl)
            let cfg = strongSelf.serverConfig
            NSWorkspace.shared.open(strongSelf.serverConfig.storeUrl)
            
            let serveCmd = CliCmd.server(.update(cfg))
            strongSelf.theViewController.requestToStart(withCommands: [startCmd.cmd,
                                                                       serveCmd.cmd])
        }
    }

    //MARK:- User Actions
    //MARK:
    @IBAction func requestToStart(_ sender: NSButton) {
        if sender.state == .off {
            startSequence()
        } else {
            theViewController.requestToStop()
        }
        sender.title = (sender.state == .on ?"▸" :"◻️")
    }
    
    @IBAction func requestToSendCmd(_ sender: NSButton) {
        guard let valueToSend = toolbarCommand?.stringValue else {
            return
        }
        theViewController.requestToSend(cmd: valueToSend)
    }
    
    @IBAction func requestForUserConfig(_ sender: NSButton) {
        guard let configUpdateVC = storyboard?
            .instantiateController(withIdentifier: .init(stringLiteral: "ConfigServerViewController"))
            as? ConfigServerViewController else {
            return
        }
        configUpdateVC.config = serverConfig
        configUpdateVC.updateConfigAction = { [weak self] (newConfig) in
            self?.workQueue.async { [weak self] in
                guard let strongSelf = self else { return }
                let serveCmd = CliCmd.server(.update(newConfig))
                strongSelf.serverConfig = newConfig
                strongSelf.theViewController.requestToSend(cmd: serveCmd.cmd)
            }
        }
        theViewController.presentAsSheet(configUpdateVC)
    }
    
}
