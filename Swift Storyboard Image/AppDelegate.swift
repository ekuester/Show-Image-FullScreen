//
//  AppDelegate.swift
//  Swift Storyboard Image
//
//  show an image fitted to screen size, full screen mode is possible
//
//  Created by Erich Küster on July 31, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // application should terminate
        return true
    }

    // look at <https://www.brandpending.com/2016/02/21/opening-and-saving-custom-document-types-from-a-swift-cocoa-application/>
    // Swift 3 migrator changed a little
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // invoked when an item of recent documents is clicked
        let fileURL = URL(fileURLWithPath: filename)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "com.image.openfile"), object: fileURL)
        return true
    }
    
}

