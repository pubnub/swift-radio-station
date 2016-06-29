//
//  StationViewController.swift
//  RadioStation
//
//  Created by Keith Martin on 6/22/16.
//  Copyright © 2016 Keith Martin. All rights reserved.
//

/*
 * This class receives messages from the radio station the user is subscribed to
 * A user can upvote and downvote the song that is playing
 */

import UIKit
import PubNub
import MediaPlayer

class StationViewController: UIViewController, PNObjectEventListener {
    
    let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var channelName: String!
    var stationName: String!
    
    @IBOutlet weak var trackName: UILabel!
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var thumbsUpButton: UIButton!
    @IBOutlet weak var thumbsDownButton: UIButton!
    let controller = MPMusicPlayerController.applicationMusicPlayer()
    
    
    //Publish a upvote to the subscribed channel
    @IBAction func thumbsUp(sender: AnyObject) {
        appDelegate.client.publish(["action" : "thumbsUp"], toChannel: channelName) { (status) in
            if !status.error {
                self.thumbsDownButton.backgroundColor = UIColor.clearColor()
                self.thumbsUpButton.backgroundColor = UIColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1.0)
            } else {
                self.showAlert("Error", error: "Network error")
            }
        }
    }
    
    //Publish a downvote to the subscribed channel
    @IBAction func thumbsDown(sender: AnyObject) {
        appDelegate.client.publish(["action" : "thumbsDown"], toChannel: channelName) { (status) in
            if !status.error {
                self.thumbsUpButton.backgroundColor = UIColor.clearColor()
                self.thumbsDownButton.backgroundColor = UIColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1.0)
            } else {
                self.showAlert("Error", error: "Network error")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    override func viewDidAppear(animated: Bool) {
        appDelegate.client.addListener(self)
        appDelegate.client.subscribeToChannels([channelName], withPresence: true)
        self.title = "Radio station - \(stationName)"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Recieve song data to play
    func client(client: PubNub, didReceiveMessage message: PNMessageResult) {
        if let trackId = message.data.message!["trackId"] as? String, currentPlaybackTime = message.data.message!["currentPlaybackTime"] as? Double, trackName = message.data.message!["trackName"] as? String, artistName = message.data.message!["artistName"] as? String {
            controller.setQueueWithStoreIDs([trackId])
            controller.play()
            controller.currentPlaybackTime = currentPlaybackTime
            self.trackName.text = trackName
            self.artistName.text = artistName
            thumbsDownButton.backgroundColor = UIColor.clearColor()
            thumbsUpButton.backgroundColor = UIColor.clearColor()
        }
    }
    
    //Unsubscribe from the radio station when they leave this view
    //The song that is currently playing will keep playing until finished unless the user joins a different station
    override func viewDidDisappear(animated: Bool) {
        appDelegate.client.unsubscribeFromChannels([channelName], withPresence: true)
    }
    
    //Dialogue showing error
    func showAlert(title: String, error: String) {
        let alertController = UIAlertController(title: title, message: error, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true, completion:nil)
    }
}
