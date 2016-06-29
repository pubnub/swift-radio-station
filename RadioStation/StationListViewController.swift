//
//  StationListViewController.swift
//  RadioStation
//
//  Created by Keith Martin on 6/22/16.
//  Copyright © 2016 Keith Martin. All rights reserved.
//

/*
 * This class displays all radio stations created 
 * A user can touch a cell to segue to that radio station
 */

import UIKit
import PubNub

class StationListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    var stationNames: [String] = []
    var channelNames: [String] = []
    let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Store the PubNub channelName in the detailTextLabel
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = stationNames[stationNames.startIndex.advancedBy(indexPath.row)]
        cell.detailTextLabel?.text = channelNames[channelNames.startIndex.advancedBy(indexPath.row)]
        cell.detailTextLabel?.hidden = true
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channelNames.count
    }
    
    //Segue to that radio station and pass the channel name and station name
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        let stationVC = self.storyboard?.instantiateViewControllerWithIdentifier("StationViewController") as! StationViewController
        stationVC.channelName = (cell?.detailTextLabel?.text)!
        stationVC.stationName = (cell?.textLabel?.text)!
        self.navigationController?.pushViewController(stationVC, animated: true)
    }
    
    //Dialogue showing error
    func showAlert(title: String, error: String) {
        let alertController = UIAlertController(title: title, message: error, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true, completion:nil)
    }
    
}
