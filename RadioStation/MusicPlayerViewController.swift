//
//  QueueViewController.swift
//  RadioStation
//
//  Created by Keith Martin on 6/16/16.
//  Copyright © 2016 Keith Martin. All rights reserved.
//

/*
 * This class plays the songs in the playback queue
 * It publishes the song data to anyone who subscribes to this channel
 * Data is published when a user joins or the DJ skips forward or backwards
 */

import UIKit
import MediaPlayer
import PubNub

class MusicPlayerViewController: UIViewController, PNObjectEventListener {
    
    var queue: [SongData] = []
    var trackIds: [String] = []
    let controller: MPMusicPlayerController = MPMusicPlayerController.applicationMusicPlayer()
    let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var channelName: String = ""
    
    @IBOutlet weak var thumbsDownCount: UILabel!
    @IBOutlet weak var thumbsUpCount: UILabel!
    @IBOutlet weak var trackName: UILabel!
    @IBOutlet weak var artistName: UILabel!
    
    //Skip to the next track and publish the trackId, currentPlaybackTime, trackName and artistName to the current channel
    @IBAction func skipForwards(sender: AnyObject) {
        controller.skipToNextItem()
        if controller.indexOfNowPlayingItem < queue.count {
        trackName.text = queue[controller.indexOfNowPlayingItem].trackName
        artistName.text = queue[controller.indexOfNowPlayingItem].artistName
        appDelegate.client.publish(["trackId" : trackIds[controller.indexOfNowPlayingItem], "currentPlaybackTime" : controller.currentPlaybackTime, "trackName" : queue[controller.indexOfNowPlayingItem].trackName!, "artistName" : queue[controller.indexOfNowPlayingItem].artistName!], toChannel: channelName, withCompletion: { (status) in
            if !status.error {
                self.controller.play()
                dispatch_async(dispatch_get_main_queue(), {
                    self.thumbsUpCount.text = "0"
                    self.thumbsDownCount.text = "0"
                })
            } else {
                self.showAlert("Error", error: "Network error")
            }
        })
        }
    }
    
    //Skip to the previous track and publish the trackId, currentPlaybackTime, trackName and artistName to the current channel
    @IBAction func skipBackwards(sender: AnyObject) {
        controller.skipToPreviousItem()
        if controller.indexOfNowPlayingItem < queue.count {
        trackName.text = queue[controller.indexOfNowPlayingItem].trackName
        artistName.text = queue[controller.indexOfNowPlayingItem].artistName
        appDelegate.client.publish(["trackId" : trackIds[controller.indexOfNowPlayingItem], "currentPlaybackTime" : controller.currentPlaybackTime, "trackName" : queue[controller.indexOfNowPlayingItem].trackName!, "artistName" : queue[controller.indexOfNowPlayingItem].artistName!], toChannel: channelName, withCompletion: { (status) in
            if !status.error {
                self.controller.play()
                dispatch_async(dispatch_get_main_queue(), {
                    self.thumbsUpCount.text = "0"
                    self.thumbsDownCount.text = "0"
                })
            } else {
                self.showAlert("Error", error: "Network error")
            }
        })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.client.addListener(self)
        for song in queue {
            trackIds.append(String (song.trackId!))
        }
        controller.setQueueWithStoreIDs(trackIds)
        controller.play()
        trackName.text = queue[controller.indexOfNowPlayingItem].trackName
        artistName.text = queue[controller.indexOfNowPlayingItem].artistName
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Unsubscribe when leaving radio station view
    override func viewWillDisappear(animated: Bool) {
        appDelegate.client.unsubscribeFromChannels([channelName], withPresence: true)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queue.count
    }
    
    //Listen if a user joins and and publish the trackId, currentPlaybackTime, trackName and artistName to the current channel
    func client(client: PubNub, didReceivePresenceEvent event: PNPresenceEventResult) {
        var playbackTime: Double!
        if controller.currentPlaybackTime.isNaN || controller.currentPlaybackTime.isInfinite {
            playbackTime = 0.0
        } else {
            playbackTime = controller.currentPlaybackTime
        }
        if event.data.presenceEvent == "join" {
            appDelegate.client.publish(["trackId" : trackIds[controller.indexOfNowPlayingItem], "currentPlaybackTime" : playbackTime, "trackName" : queue[controller.indexOfNowPlayingItem].trackName!, "artistName" : queue[controller.indexOfNowPlayingItem].artistName!], toChannel: channelName, withCompletion: { (status) in
                if status.error {
                    self.showAlert("Error", error: "Network error")
                }
            })
        }
    }
    
    //Update thumbs up and thumbs down counts
    func client(client: PubNub, didReceiveMessage message: PNMessageResult) {
        if "thumbsUp" == message.data.message!["action"] as? String {
            let count = Int(thumbsUpCount.text!)
            thumbsUpCount.text = String(count! + 1)
        } else if "thumbsDown" == message.data.message!["action"] as? String {
            let count = Int(thumbsDownCount.text!)
            thumbsDownCount.text = String(count! + 1)
        }
    }
    
    //Dialogue showing error
    func showAlert(title: String, error: String) {
        let alertController = UIAlertController(title: title, message: error, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true, completion:nil)
    }
}
