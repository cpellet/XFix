//
//  ViewController.swift
//  xfix
//
//  Created by cyrus pellet on 4/7/20.
//

import Cocoa
import IOKit
import IOKit.serial
import ORSSerial
import MapKit

class ViewController: NSViewController, ORSSerialPortDelegate, NmeaParserDelegate, NSTableViewDelegate, NSTableViewDataSource {
    
    func didUpdateGPSData(_sender: NmeaParser, data: NmeaParser.GPSData) {
        locationAnnotation.coordinate = data.location.coordinate
        mapView.removeAnnotation(locationAnnotation)
        mapView.addAnnotation(locationAnnotation)
        bigLabel.stringValue = "\(data.latitude) \(data.NS), \(data.longitude) \(data.EW)"
        dataLabel.stringValue = "Time: \(data.location.timestamp) \n Speed: \(data.speedKph) km/h \n Altitude: \(data.altitude)\(data.altitudeUnit.lowercased())"
        statusLabel.textColor = data.dimensionalfixType == .Unavailable ? .systemRed : .systemGreen
        switch data.dimensionalfixType{
        case .Unavailable:
            statusLabel.stringValue = "No fix \(data.fixAcquisitionMode == .Manual ? "(Manual)" : "(Auto)")"
        case.F2D:
            statusLabel.stringValue = "2D fix \(data.fixAcquisitionMode == .Manual ? "(Manual)" : "(Auto)")"
        case.F3D:
            statusLabel.stringValue = "3D fix \(data.fixAcquisitionMode == .Manual ? "(Manual)" : "(Auto)")"
        }
        errorLabel.stringValue = " Precision stats: \n HDOP:\(data.HDOP)\n VDOP:\(data.VDOP)\n PDOP:\(data.PDOP)\n Geo-sep:\(data.geoidalSeparation)\(data.geoidalSeparationUnit.lowercased())"
        satTable.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return parser.data.satData.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = parser.data.satData[row]
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "dataCell"), owner: self) as? NSTableCellView {
            switch tableColumn?.identifier {
            case NSUserInterfaceItemIdentifier(rawValue: "a"):
                cell.textField?.stringValue = String(item.SVID)
            case NSUserInterfaceItemIdentifier(rawValue: "b"):
                cell.textField?.stringValue = String(item.elevation)
            case NSUserInterfaceItemIdentifier(rawValue: "c"):
                cell.textField?.stringValue = String(item.azimuth)
            case NSUserInterfaceItemIdentifier(rawValue: "d"):
                cell.textField?.stringValue = String(item.SNR)
            default:
                return nil
            }
            return cell
        }
        return nil
    }
    
    
    var pendingString = ""
    var pendingSentences = Queue<String>()
    let parser = NmeaParser()
    let locationAnnotation = MKPointAnnotation()
    @IBOutlet weak var bigLabel: NSTextField!
    @IBOutlet weak var dataLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var satTable: NSTableView!
    @IBOutlet weak var errorLabel: NSTextField!
    
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("SERIAL PORT DISCONNECTED AT \(serialPort.path)")
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("SERIAL PORT WAS OPENED AT \(serialPort.path)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        if let string = String(data: data, encoding: .utf8){
            pendingString.append(string)
            pendingString.enumerateLines{line, _ in
                if(line.last != self.pendingString.last){
                    if line.contains("$"){
                        self.pendingSentences.enqueue(line)
                        self.pendingString = self.pendingString.replacingOccurrences(of: line, with: "")
                    }
                }
            }
            while !pendingSentences.isEmpty{
                parser.parseSentence(data: pendingSentences.dequeue()!)
            }
        }
    }
    
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let serialPort = ORSSerialPort(path: ORSSerialPortManager.shared().availablePorts[0].path)
        serialPort!.baudRate = 9600
        serialPort!.delegate = self
        serialPort!.open()
        parser.delegate = self
        satTable.delegate = self
        satTable.dataSource = self
    }
}
