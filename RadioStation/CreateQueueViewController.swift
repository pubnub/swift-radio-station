//
//  ViewController.swift
//  RadioStation
//
//  Created by Keith Martin on 6/16/16.
//  Copyright © 2016 Keith Martin. All rights reserved.
//

/* 
 * This class uses the iTunes search API to pull up songs the user searches for
 * User then touches cell to add to playback queue
 * The "Go DJ playlist button" segues the user to their radio station
 */

import UIKit
import MediaPlayer
import PubNub
import Alamofire
import StoreKit

protocol AddSongDelegate: class {
    func addSongToQueue()
}

struct SongData {
    var artWork: UIImage?
    var trackName: String?
    var artistName: String?
    var trackId: String?
}

class CreateQueueViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, PNObjectEventListener {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    var tableData = []
    var queue: [SongData] = []
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    
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
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        let controller = SKCloudServiceController()
        //Check if user is a Apple Music member
        controller.requestCapabilitiesWithCompletionHandler({ (capabilities, error) in
            if error != nil {
                dispatch_async(dispatch_get_main_queue(), {
                    self.showAlert("Capabilites error", error: "You must be an Apple Music member to use this application")
                })
            }
        })
    }
    
    override func viewDidAppear(animated: Bool) {
        queue = []
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        //Search iTunes with user input
        if searchBar.text != nil {
            let search = searchBar.text!.stringByReplacingOccurrencesOfString(" ", withString: "+")
            searchItunes(search)
            searchBar.resignFirstResponder()
        }
    }
    
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
    
    
    //Only displaying 10 of the search items
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableData.count < 10 {
            return tableData.count
        }
        return 10
    }
    
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
            imgData = NSData(contentsOfURL: imgURL)  {
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
    
    //Create unique PubNub channel by concatenating the current timestamp to the name of the radio station
    func createValidPNChannel(channelName: String) -> String {
        let regex = try? NSRegularExpression(pattern: "[\\W]", options: .CaseInsensitive)
        var validChannelName = regex!.stringByReplacingMatchesInString(channelName, options: [], range: NSRange(0..<channelName.characters.count), withTemplate: "")
        validChannelName += "\(NSDate().timeIntervalSince1970)"
        validChannelName = validChannelName.stringByReplacingOccurrencesOfString(".", withString: "")
        return validChannelName
    }
    
    //Dialogue showing error
    func showAlert(title: String, error: String) {
        let alertController = UIAlertController(title: title, message: error, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true, completion:nil)
    }
}

