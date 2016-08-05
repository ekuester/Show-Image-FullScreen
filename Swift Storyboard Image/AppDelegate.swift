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

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        // application should terminate
        return true
    }

    // look at <https://www.brandpending.com/2016/02/21/opening-and-saving-custom-document-types-from-a-swift-cocoa-application/>
    func application(sender: NSApplication, openFile filename: String) -> Bool {
        // invoked when an item of recent documents is clicked
        let fileURL = NSURL(fileURLWithPath: filename)
        NSNotificationCenter.defaultCenter().postNotificationName("com.image.openfile", object: fileURL)
        return true
    }
    
}

