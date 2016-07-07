# Realtime Radio Station iOS App

This application allows a user to DJ a radio station or listen to one that has been created. It uses PubNub's global data stream network broadcast and listen in realtime.

Searching for tracks to add to a playlist is handled through the iTunes Search API. Those tracks are played using the Apple Music API. This app has been written for the following tutorial, https://www.pubnub.com/blog/2016-07-07-realtime-radio-station-application-using-apple-music-and-itunes-search-apis/.

#DJ a Radio station
![DJ a radio station demo] (https://i.imgsafe.org/e9cd8be358.gif)

Search iTunes and display results
Once it’s confirmed that the user is a Apple Music member, the searchItunes() function will use the iTunes Search API to make a GET request for whatever input the user provided from the searchBarSearchButtonClicked() function:

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

Creating a Radio Station
After the user finishes adding tracks to their playback queue, they can create a radio station. A dialogue is presented for the user to name their radio station. This name is also used for their channel. A PubNub channel cannot contain a comma, colon, asterisk, slash or backslash, the createValidPNChannel() makes sure of this by deleting any of those characters in the name. It then gets the current timestamp to concatenate to the name so the channel will have a unique name.

//Create station name and segue to radio station if playback queue isn't empty
@IBAction func takeInputAndSegue(sender: AnyObject) {
    let alert = UIAlertController(title: "Name your radio station!", message: nil, preferredStyle: .Alert)
    alert.addTextFieldWithConfigurationHandler(nil)
    alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
    if !self.queue.isEmpty {
        let radioStationName = alert.textFields![0] as UITextField
    if !radioStationName.text!.isEmpty && radioStationName.text?.characters.count <= 60 {
        let stationName = radioStationName.text!
        //Adds a timestamp to the station name to make it a unique channel name
        let channelName = self.createValidPNChannel(stationName)
        //Publish station to a list of all stations created
        self.appDelegate.client.publish(["stationName" : stationName, "channelName" : channelName], toChannel: "All_Stations", withCompletion: { (status) in
            if status.error {
                self.showAlert("Error", error: "Network error")
            }
            self.appDelegate.client.subscribeToChannels([channelName], withPresence: true)
            dispatch_async(dispatch_get_main_queue(), {
                //Segue to the radio station
                let musicPlayerVC = self.storyboard?.instantiateViewControllerWithIdentifier("MusicPlayerViewController") as! MusicPlayerViewController
                musicPlayerVC.queue = self.queue
                musicPlayerVC.channelName = channelName
                self.navigationController?.pushViewController(musicPlayerVC, animated: true)
            })
          })
      } else {
          dispatch_async(dispatch_get_main_queue(), {
              self.showAlert("Try again", error: "Radio station name can't be empty or more than 60 characters")
          })
      }
   } else {
      dispatch_async(dispatch_get_main_queue(), {
          self.showAlert("Try again", error: "Playlist cannot be empty")
      })
   }
  }))
 self.presentViewController(alert, animated: true, completion: nil)
}
//Create unique PubNub channel by concatenating the current timestamp to the name of the radio station
func createValidPNChannel(channelName: String) -> String {
    let regex = try? NSRegularExpression(pattern: "[\\W]", options: .CaseInsensitive)
    var validChannelName = regex!.stringByReplacingMatchesInString(channelName, options: [], range: NSRange(0..<channelName.characters.count), withTemplate: "")
    validChannelName += "\(NSDate().timeIntervalSince1970)"
    validChannelName = validChannelName.stringByReplacingOccurrencesOfString(".", withString: "")
    return validChannelName
}
