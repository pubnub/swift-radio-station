# Realtime Radio Station iOS App

##Introduction

This application allows a user to DJ a radio station or listen to one that has been created. It uses PubNub's global data stream network broadcast and listen in realtime.

Searching for tracks to add to a playlist is handled through the iTunes Search API. Those tracks are played using the Apple Music API. This app has been written for the following tutorial, https://www.pubnub.com/blog/2016-07-07-realtime-radio-station-application-using-apple-music-and-itunes-search-apis/.

##Code samples

###DJ a Radio station
![DJ a radio station demo] (https://i.imgsafe.org/e9cd8be358.gif)

####Search iTunes and display results
Once it’s confirmed that the user is a Apple Music member, the searchItunes() function will use the iTunes Search API to make a GET request for whatever input the user provided from the searchBarSearchButtonClicked() function:

```swift
//Search iTunes and display results in table view
func searchItunes(searchTerm: String) {
    Alamofire.request(.GET, "https://itunes.apple.com/search?term=\(searchTerm)&entity=song")
    .validate()
    .responseJSON { response in
        switch response.result {
        case .Success:
            if let responseData = response.result.value as? NSDictionary {
                if let songResults = responseData.valueForKey("results") as? [NSDictionary] {
                    self.tableData = songResults
                    self.tableView!.reloadData()
                }
            }
         case .Failure(let error):
             self.showAlert("Error", error: error.description)
         }
      }
}
func searchBarSearchButtonClicked(searchBar: UISearchBar) {
    //Search iTunes with user input
    if searchBar.text != nil {
        let search = searchBar.text!.stringByReplacingOccurrencesOfString(" ", withString: "+")
        searchItunes(search)
        searchBar.resignFirstResponder()
    }
}
``` 

Once we get this data, it will be displayed in a table view allowing the user to pick a track and add it to their playback queue:
```swift
//Display iTunes search results
func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: nil)
    if let rowData: NSDictionary = self.tableData[indexPath.row] as? NSDictionary,
       urlString = rowData["artworkUrl60"] as? String,
       imgURL = NSURL(string: urlString),
       imgData = NSData(contentsOfURL: imgURL) {
       cell.imageView?.image = UIImage(data: imgData)
       cell.textLabel?.text = rowData["trackName"] as? String
       cell.detailTextLabel?.text = rowData["artistName"] as? String
    }
    return cell
}
//Add song to playback queue if user selects a cell
func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let indexPath = tableView.indexPathForSelectedRow
    if let rowData: NSDictionary = self.tableData[indexPath!.row] as? NSDictionary, urlString = rowData["artworkUrl60"] as? String,
        imgURL = NSURL(string: urlString),
        imgData = NSData(contentsOfURL: imgURL) {
        queue.append(SongData(artWork: UIImage(data: imgData), trackName: rowData["trackName"] as? String, artistName: rowData["artistName"] as? String, trackId: String (rowData["trackId"]!)))
        //Show alert telling the user the song was added to the playback queue
        let addedTrackAlert = UIAlertController(title: nil, message: "Added track!", preferredStyle: .Alert)
        self.presentViewController(addedTrackAlert, animated: true, completion: nil)
        let delay = 0.5 * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            addedTrackAlert.dismissViewControllerAnimated(true, completion: nil)
        })
        tableView.deselectRowAtIndexPath(indexPath!, animated: true)
    }
}
```

####DJ the Radio Station
Once a user has their own radio station, the tracks they added to their queue will begin to play. With PubNub’s Presence feature, we can detect when a user has joined our channel. Once they do, we will send out the track data and current playback time so they can listen at the same playback position on their device.
````swift
//Listen if a user joins and and publish the trackId, currentPlaybackTime, trackName and artistName to the current channel
func client(client: PubNub, didReceivePresenceEvent event: PNPresenceEventResult) {
    var playbackTime: Double!
    if controller.currentPlaybackTime.isNaN || controller.currentPlaybackTime.isInfinite {
        playbackTime = 0.0
    } else {
        playbackTime = controller.currentPlaybackTime
    }
    if event.data.presenceEvent == "join" {
        appDelegate.client.publish(["trackId" : trackIds[controller.indexOfNowPlayingItem], "currentPlaybackTime" : playbackTime, "trackName" : queue[controller.indexOfNowPlayingItem].trackName!, "artistName" : queue[controller.indexOfNowPlayingItem].artistName!], toChannel:  channelName, withCompletion: { (status) in
            if status.error {
                self.showAlert("Error", error: "Network error")
            }
        })
    }
}
````
If the DJ skips forwards or backwards, we’ll publish a message on the channel with the track data and current playback time again.

````swift
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
````
The DJ is also listening for up and down vote messages on this channel to know if the listeners like what is playing.
````swift
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
````

###Listen to a Radio Station

![DJ a radio station demo] (https://i.imgsafe.org/eaa1dafa05.gif)

To listen to a radio station, a user chooses from a table view of radio stations and they automatically subscribe to the channel from the cell they selected. In order to get these radio stations, we use PubNub’s storage and playback feature to retrieve all of the radio stations that have been created.
````swift
override func viewDidAppear(animated: Bool) {
        stationNames.removeAll()
        channelNames.removeAll()
        //Go through the history of the channel holding all stations created
        //Update table view with history list
        appDelegate.client.historyForChannel("All_Stations") { (result, status) in
            for message in (result?.data.messages)! {
                if let stationName = message["stationName"] as? String, channelName = message["channelName"] as? String{
                    self.stationNames.append(stationName)
                    self.channelNames.append(channelName)
                }
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
            })
        }
    }
````
The user is also listening for messages on this channel with the addListener() function in viewDidAppear() above . As explained before, the DJ will send a message to whoever joins the channel. The user listening to the radio station will then listen for the incoming song data.
````swift
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
````
They can also send their upvotes and downvotes by simply publishing to the channel.
````swift
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
````
##Installation

###Installing PubNub with CocoaPods
If you’ve never used CocoaPods before, check out how to [install CocoaPods and use it](https://cocoapods.org/). The Podfile for this project will look like this:
````swift
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
platform :ios, '9.0'
target 'RadioStation' do
  pod 'PubNub'
  pod 'Alamofire', '~> 3.4'
end
````
##Credits

###App Icons
"dj.png" - Created by Sergey Demushkin from Noun Project

"fast_forward.png" - Created by Alex Audo Samora from Noun Project

"listen.png" - Created by artwork bean from the Noun Project

"rewind.png" - Created by Alex Audo Samora from Noun Project

"thumbs_down.png" - Created by useiconic.com from Noun Project

"thumbs_up.png" - Created by useiconic.com from Noun Project 
