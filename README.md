# Realtime Radio Station iOS App

This application allows a user to DJ a radio station or listen to one that has been created. It uses PubNub's global data stream network broadcast and listen in realtime.

Searching for tracks to add to a playlist is handled through the iTunes Search API. Those tracks are played using the Apple Music API. This app has been written for the following tutorial, https://www.pubnub.com/blog/2016-07-07-realtime-radio-station-application-using-apple-music-and-itunes-search-apis/.

##DJ a Radio station
![DJ a radio station demo] (https://i.imgsafe.org/e9cd8be358.gif)

###Search iTunes and display results
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
