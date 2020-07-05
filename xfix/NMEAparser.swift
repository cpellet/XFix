//
//  NMEAparser.swift
//  xfix
//
//  Created by cyrus pellet on 4/7/20.
//

import Foundation

import CoreLocation
import Foundation

class NmeaParser: NSObject{
    
    var data: GPSData = GPSData(deviceInfo: "", location: CLLocation(), latitude: CLLocationDegrees(), longitude: CLLocationDegrees(), fixAcquisitionMode: .Automatic, dimensionalfixType: .Unavailable, PDOP: -1.0, HDOP: -1.0, VDOP: -1.0, satCount: 0, satData: [], NS: "", EW: "", fixType: .NoFix, altitude: -1.0, altitudeUnit: "", geoidalSeparation: -1.0, geoidalSeparationUnit: "", deltaTimeSeconds: -1, stationID: "", track: -1.0, trueNorth: false, magneticTrack: -1.0, speedKnots: -1.0, speedKph: -1.0)
    weak var delegate: NmeaParserDelegate?
    
    
    public func parseSentence(data: String) -> Any? {
        let splittedString = data.components(separatedBy: ",")
        
        if let type = splittedString.first {            
            switch type {
            case "$GPRMC":
                let sentence = RmcSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid RMC"}
                delegate?.didParseRMCSentence(self, data: data)
                self.data.location = data
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPGSA":
                let sentence = GsaSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid GSA"}
                delegate?.didParseGSASentence(self, data: data)
                self.data.HDOP = data.HDOP
                self.data.PDOP = data.PDOP
                self.data.VDOP = data.VDOP
                self.data.dimensionalfixType = data.fixType
                self.data.fixAcquisitionMode = data.mode
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPGSV":
                let sentence = GsvSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid GSV"}
                delegate?.didParseGSVSentence(self, data: data)
                for sat in data.satdata{
                    if(!self.data.satData.contains{$0.SVID == sat.SVID}){
                        self.data.satData.append(sat)
                    }
                }
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPGLL":
                let sentence = GllSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid GLL"}
                delegate?.didParseGLLSentence(self, data: data)
                self.data.EW = data.ew
                self.data.NS = data.ns
                self.data.latitude = data.lat
                self.data.longitude = data.long
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPGGA":
                let sentence = GgaSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid GGA"}
                delegate?.didParseGGASentence(self, data: data)
                self.data.satCount = data.satcount
                self.data.altitude = data.alt
                self.data.altitudeUnit = data.altu
                self.data.deltaTimeSeconds = Int(data.deltat)
                self.data.fixType = data.fixtype
                self.data.geoidalSeparation = data.gsep
                self.data.geoidalSeparationUnit = data.gsepu
                self.data.HDOP = data.hdop
                self.data.latitude = data.lat
                self.data.longitude = data.long
                self.data.NS = data.ns
                self.data.EW = data.ew
                self.data.stationID = data.refid
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPVTG":
                let sentence = VtgSentence(rawSentence: splittedString)
                guard let data = sentence.parse() else {return "Invalid VTG"}
                delegate?.didParseVTGSentence(self, data: data)
                self.data.magneticTrack = data.magtrack
                self.data.trueNorth = (data.tnorth == "N") ? true : false
                self.data.track = data.track
                self.data.speedKph = data.speedk
                self.data.speedKnots = data.speedn
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
                return data
            case "$GPTXT":
                delegate?.didParseDeviceData(self, data: splittedString[4])
                self.data.deviceInfo.append(splittedString[4])
                delegate?.didUpdateGPSData(_sender: self, data: self.data)
            default:
                print("NMEA Type \(String(describing: type)) unknown.")
            }
        }
        return nil
    }
    
    struct GPSData{
        var deviceInfo: String
        var location: CLLocation
        var latitude: CLLocationDegrees
        var longitude: CLLocationDegrees
        var fixAcquisitionMode: GsaSentence.GSAMode
        var dimensionalfixType: GsaSentence.GSAFixType
        var PDOP: Double
        var HDOP: Double
        var VDOP: Double
        var satCount: Int
        var satData: [GsvSentence.GSVSatData]
        var NS: String
        var EW: String
        var fixType: GgaSentence.GGAFixType
        var altitude: Double
        var altitudeUnit: String
        var geoidalSeparation: Double
        var geoidalSeparationUnit: String
        var deltaTimeSeconds: Int
        var stationID: String
        var track: Double
        var trueNorth: Bool
        var magneticTrack: Double
        var speedKnots: Double
        var speedKph: Double
    }
}

protocol NmeaSentence {
    var rawSentence: [String] { get }
    init(rawSentence: [String])
    func type() -> String
}

public class RmcSentence: NmeaSentence {
    
    var rawSentence: [String]
    
    enum Param: Int {
        case TYPE = 0
        case TIME = 1
        case STATUS = 2
        case LATITUDEDIR = 3
        case LATITUDE = 4
        case LONGITUDEDIR = 5
        case LONGITUDE = 6
        case SPEED = 7
        case COURSE = 8
        case DATE = 9
        case DEVIATION = 10
        case SIGN = 11
        case SIGNAL = 12
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPRMC"
    }
    
    func parse() -> CLLocation? {
        let splittedString = self.rawSentence
        
        if splittedString.count < 12 {
            print("Invalid RMC string!")
            return nil
        }
        
        let rawTime = splittedString[RmcSentence.Param.TIME.rawValue]
        let rawLatitude = (splittedString[RmcSentence.Param.LATITUDE.rawValue], splittedString[RmcSentence.Param.LATITUDEDIR.rawValue])
        let rawLongitude = (splittedString[RmcSentence.Param.LONGITUDE.rawValue], splittedString[RmcSentence.Param.LONGITUDEDIR.rawValue])
        let rawSpeed = splittedString[RmcSentence.Param.SPEED.rawValue] // knots
        let rawCourse = splittedString[RmcSentence.Param.COURSE.rawValue] // degree
        let rawDate = splittedString[RmcSentence.Param.DATE.rawValue]
        let latitudeInDegree = convertLatitudeToDegree(with: rawLatitude.1)
        let longitudeInDegree = convertLongitudeToDegree(with: rawLongitude.1)
        let coordinate = CLLocationCoordinate2D(latitude: latitudeInDegree,longitude: longitudeInDegree)
        var course = CLLocationDirection(-1)
        if !rawCourse.isEmpty, let tempCourse = CLLocationDirection(rawCourse) {
            course = tempCourse
        }
        
        var speed = CLLocationSpeed(-1)
        if !rawSpeed.isEmpty {
            if #available(iOS 10.0, *) {
                let speedInMs = Measurement(value: Double(rawSpeed)!, unit: UnitSpeed.knots).converted(to: UnitSpeed.metersPerSecond)
                speed = CLLocationSpeed(speedInMs.value)
            } else {
                speed = CLLocationSpeed(Double(rawSpeed)! * 0.514)
            }
        }
        
        let concatenatedDate = rawDate + rawTime
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        if rawDate.isEmpty {
            dateFormatter.dateFormat = "hhmmss.SSS" // 025816.16
        } else {
            dateFormatter.dateFormat = "ddMMyyHHmmss.SSS"
        }
        
        var timestamp = Date()
        if let date = dateFormatter.date(from: concatenatedDate) {
            timestamp = date
        }
        
        let altitude = CLLocationDistance(0)
        let horizontalAccuracy = CLLocationAccuracy(0)
        let verticalAccuracy = CLLocationAccuracy(0)
        return CLLocation(coordinate: coordinate,
                          altitude: altitude,
                          horizontalAccuracy: horizontalAccuracy,
                          verticalAccuracy: verticalAccuracy,
                          course: course,
                          speed: speed,
                          timestamp: timestamp)
    }

    func convertLatitudeToDegree(with stringValue: String) -> Double {
        return Double(stringValue.prefix(2))! +
            Double(stringValue.suffix(from: String.Index.init(encodedOffset: 2)))! / 60
    }
    
    func convertLongitudeToDegree(with stringValue: String) -> Double {
        return Double(stringValue.prefix(3))! +
            Double(stringValue.suffix(from: String.Index.init(encodedOffset: 3)))! / 60
    }
}

public class GsaSentence: NmeaSentence {
    
    var rawSentence: [String]

    enum Param: Int {
        case TYPE = 0
        case MODE = 1
        case FIX = 2
        case SV1 = 3
        case SV2 = 4
        case SV3 = 5
        case SV4 = 6
        case SV5 = 7
        case SV6 = 8
        case SV7 = 9
        case SV8 = 10
        case SV9 = 11
        case SV10 = 12
        case SV11 = 13
        case SV12 = 14
        case PDOP = 15
        case HDOP = 16
        case VDOP = 17
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPGSA"
    }
    
    enum GSAMode: String{
        case Manual = "M"
        case Automatic = "A"
    }
    
    enum GSAFixType: Int{
        case Unavailable = 1
        case F2D = 2
        case F3D = 3
    }
    
    struct GSAData{
        let mode: GSAMode
        let fixType: GSAFixType
        let SVIDs: [String]
        let PDOP: Double
        let HDOP: Double
        let VDOP: Double
    }
    
    func parse() -> GSAData? {
        let splittedString = self.rawSentence
        
        if splittedString.count < 17 {
            print("Invalid GSA string!")
            return nil
        }
        
        let rawMode = splittedString[GsaSentence.Param.MODE.rawValue]
        let rawFix = splittedString[GsaSentence.Param.FIX.rawValue]
        let rawSVS = [splittedString[GsaSentence.Param.SV1.rawValue],                              splittedString[GsaSentence.Param.SV2.rawValue], splittedString[GsaSentence.Param.SV3.rawValue], splittedString[GsaSentence.Param.SV4.rawValue], splittedString[GsaSentence.Param.SV5.rawValue], splittedString[GsaSentence.Param.SV6.rawValue], splittedString[GsaSentence.Param.SV7.rawValue], splittedString[GsaSentence.Param.SV8.rawValue], splittedString[GsaSentence.Param.SV9.rawValue], splittedString[GsaSentence.Param.SV10.rawValue], splittedString[GsaSentence.Param.SV11.rawValue], splittedString[GsaSentence.Param.SV12.rawValue]]
        let rawPDOP = splittedString[GsaSentence.Param.PDOP.rawValue]
        let rawHDOP = splittedString[GsaSentence.Param.HDOP.rawValue]
        let rawVDOP = splittedString[GsaSentence.Param.VDOP.rawValue]
        return GSAData(mode: GSAMode(rawValue: rawMode)!, fixType: GSAFixType(rawValue: Int(rawFix)!)!, SVIDs: rawSVS, PDOP: Double(rawPDOP) ?? -1.0, HDOP: Double(rawHDOP) ?? -1.0, VDOP: Double(rawVDOP) ?? -1.0)
    }
    
}

public class GsvSentence: NmeaSentence {
    
    var rawSentence: [String]
    
    enum Param: Int {
        case TYPE = 0
        case MCOUNT = 1
        case MCURR = 2
        case SVCOUNT = 3
        case SV1PRN = 4
        case SV1ELN = 5
        case SV1AZH = 6
        case SV1SNR = 7
        case SV2PRN = 8
        case SV2ELN = 9
        case SV2AZH = 10
        case SV2SNR = 11
        case SV3PRN = 12
        case SV3ELN = 13
        case SV3AZH = 14
        case SV3SNR = 15
        case SV4PRN = 16
        case SV4ELN = 17
        case SV4AZH = 18
        case SV4SNR = 19
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPGSV"
    }
    
    struct GSVSatData{
        let SVID: Int
        let elevation: Int
        let azimuth: Int
        let SNR: Int
    }
    
    struct GSVData{
        let mcount: Int
        let mcurr: Int
        let svcount: Int
        let satdata: [GSVSatData]
    }
    
    func parse() -> GSVData? {
        let splittedString = self.rawSentence
        let rawMcount = splittedString[GsvSentence.Param.MCOUNT.rawValue]
        let rawMcurr = splittedString[GsvSentence.Param.MCURR.rawValue]
        let rawSVcount = splittedString[GsvSentence.Param.SVCOUNT.rawValue]
        let sv1 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV1PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV1ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV1AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV1SNR.rawValue]) ?? -1)
        switch splittedString.count{
        case 19...20:
            let sv2 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV2PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV2ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV2AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV2SNR.rawValue]) ?? -1)
            let sv3 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV3PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV3ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV3AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV3SNR.rawValue]) ?? -1)
            let sv4 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV4PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV4ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV4AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV4SNR.rawValue]) ?? -1)
            return GSVData(mcount: Int(rawMcount)!, mcurr: Int(rawMcurr)!, svcount: Int(rawSVcount)!, satdata: [sv1, sv2, sv3, sv4])
        case 16:
            let sv2 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV2PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV2ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV2AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV2SNR.rawValue]) ?? -1)
            let sv3 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV3PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV3ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV3AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV3SNR.rawValue]) ?? -1)
            return GSVData(mcount: Int(rawMcount)!, mcurr: Int(rawMcurr)!, svcount: Int(rawSVcount)!, satdata: [sv1, sv2, sv3])
        case 12:
            let sv2 = GSVSatData(SVID: Int(splittedString[GsvSentence.Param.SV2PRN.rawValue]) ?? -1, elevation: Int(splittedString[GsvSentence.Param.SV2ELN.rawValue]) ?? -1, azimuth: Int(splittedString[GsvSentence.Param.SV2AZH.rawValue]) ?? -1, SNR: Int(splittedString[GsvSentence.Param.SV2SNR.rawValue]) ?? -1)
            return GSVData(mcount: Int(rawMcount)!, mcurr: Int(rawMcurr)!, svcount: Int(rawSVcount)!, satdata: [sv1, sv2])
        case 8:
            return GSVData(mcount: Int(rawMcount)!, mcurr: Int(rawMcurr)!, svcount: Int(rawSVcount)!, satdata: [sv1])
        default:
            print("Invalid GSV string! Expected 20, 16, 12, or 8 elements but got \(splittedString.count) with GSV data : \(splittedString)")
            return nil
        }
    }
    
}

public class GllSentence: NmeaSentence {
    
    var rawSentence: [String]
    
    enum Param: Int {
        case TYPE = 0
        case LAT = 1
        case NS = 2
        case LONG = 3
        case EW = 4
        case CS = 5
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPGLL"
    }
    
    struct GLLData{
        let lat: CLLocationDegrees
        let ns: String
        let long: CLLocationDegrees
        let ew: String
    }
    
    func parse() -> GLLData? {
        let splittedString = self.rawSentence
        
        if splittedString.count < 5 {
            print("Invalid GLL string!")
            return nil
        }
        
        let rawlat = splittedString[GllSentence.Param.LAT.rawValue]
        let rawns = splittedString[GllSentence.Param.NS.rawValue]
        let rawlong = splittedString[GllSentence.Param.LONG.rawValue]
        let rawew = splittedString[GllSentence.Param.EW.rawValue]
        return GLLData(lat: CLLocationDegrees(rawlat)!, ns: rawns, long: CLLocationDegrees(rawlong)!, ew: rawew)
    }
}

public class GgaSentence: NmeaSentence {
    
    var rawSentence: [String]
    
    enum Param: Int {
        case TYPE = 0
        case TIME = 1
        case LAT = 2
        case NS = 3
        case LONG = 4
        case EW = 5
        case FIX = 6
        case SATCOUNT = 7
        case HDOP = 8
        case ALT = 9
        case ALTU = 10
        case GSEP = 11
        case GSEPU = 12
        case DELTAT = 13
        case REFID = 14
        case CS = 15
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPGGA"
    }
    
    enum GGAFixType: Int{
        case NoFix = 0
        case GPSFix = 1
        case DifGPSFix = 2
    }
    
    struct GGAData{
        let time: Date
        let lat: CLLocationDegrees
        let ns: String
        let long: CLLocationDegrees
        let ew: String
        let fixtype: GGAFixType
        let satcount: Int
        let hdop: Double
        let alt: Double
        let altu: String
        let gsep: Double
        let gsepu: String
        let deltat: Double
        let refid: String
    }
    
    func parse() -> GGAData? {
        let splittedString = self.rawSentence
        
        if splittedString.count < 15 {
            print("Invalid GGA string, ewpected 15 elements but got \(splittedString.count) : \(splittedString)")
            return nil
        }
        
        let rawTime = splittedString[GgaSentence.Param.TIME.rawValue]
        let rawlat = splittedString[GgaSentence.Param.LAT.rawValue]
        let rawns = splittedString[GgaSentence.Param.NS.rawValue]
        let rawlong = splittedString[GgaSentence.Param.LONG.rawValue]
        let rawew = splittedString[GgaSentence.Param.EW.rawValue]
        let rawFixType = splittedString[GgaSentence.Param.FIX.rawValue]
        let rawSatCount = splittedString[GgaSentence.Param.SATCOUNT.rawValue]
        let rawHDOP = splittedString[GgaSentence.Param.HDOP.rawValue]
        let rawAlt = splittedString[GgaSentence.Param.ALT.rawValue]
        let rawAltU = splittedString[GgaSentence.Param.ALTU.rawValue]
        let rawGsep = splittedString[GgaSentence.Param.GSEP.rawValue]
        let rawGsepU = splittedString[GgaSentence.Param.GSEPU.rawValue]
        let rawDeltaT = splittedString[GgaSentence.Param.DELTAT.rawValue]
        let rawRefID = splittedString[GgaSentence.Param.REFID.rawValue]
        
        let df = DateFormatter()
        df.timeZone = TimeZone(identifier: "GMT")
        df.dateFormat = "hhmmss.SSS" // 025816.16
        let date = df.date(from: rawTime) ?? Date()
        return GGAData(time: date, lat: CLLocationDegrees(rawlat)!, ns: rawns, long: CLLocationDegrees(rawlong)!, ew: rawew, fixtype: GGAFixType(rawValue: Int(rawFixType)!)!, satcount: Int(rawSatCount) ?? -1, hdop: Double(rawHDOP) ?? -1.0, alt: Double(rawAlt) ?? -1.0, altu: rawAltU, gsep: Double(rawGsep) ?? -1.0, gsepu: rawGsepU, deltat: Double(rawDeltaT) ?? -1.0, refid: rawRefID)
    }
}

public class VtgSentence: NmeaSentence {
    
    var rawSentence: [String]
    
    enum Param: Int {
        case TYPE = 0
        case TRACK = 1
        case TNORTH = 2
        case MAGTRACK = 3
        case MG = 4
        case SPEEDN = 5
        case MN = 6
        case SPEEDK = 7
        case MK = 8
        case CS = 9
    }
    
    required public init(rawSentence: [String]) {
        self.rawSentence = rawSentence
    }
    
    func type() -> String {
        return "$GPVTG"
    }
    
    struct VTGData{
        let track: Double
        let tnorth: String
        let magtrack: Double
        let speedn: Double
        let speedk: Double
    }
    
    func parse() -> VTGData? {
        let splittedString = self.rawSentence
        
        if splittedString.count < 9 {
            print("Invalid VTG string!")
            return nil
        }
        
        let rawTrack = splittedString[VtgSentence.Param.TRACK.rawValue]
        let rawTNorth = splittedString[VtgSentence.Param.TNORTH.rawValue]
        let rawMagTrack = splittedString[VtgSentence.Param.MAGTRACK.rawValue]
        let rawSpeedKnots = splittedString[VtgSentence.Param.SPEEDN.rawValue]
        let rawSpeedKph = splittedString[VtgSentence.Param.SPEEDK.rawValue]
        
        return VTGData(track: Double(rawTrack) ?? -1.0, tnorth: rawTNorth, magtrack: Double(rawMagTrack) ?? -1.0, speedn: Double(rawSpeedKnots) ?? -1.0, speedk: Double(rawSpeedKph) ?? -1.0)
    }
}

protocol NmeaParserDelegate: AnyObject{
    func didUpdateGPSData(_sender: NmeaParser, data: NmeaParser.GPSData)
    func didParseRMCSentence(_ sender: NmeaParser, data: CLLocation)
    func didParseGSASentence(_ sender: NmeaParser, data: GsaSentence.GSAData)
    func didParseGSVSentence(_ sender: NmeaParser, data: GsvSentence.GSVData)
    func didParseGLLSentence(_ sender: NmeaParser, data: GllSentence.GLLData)
    func didParseGGASentence(_ sender: NmeaParser, data: GgaSentence.GGAData)
    func didParseVTGSentence(_ sender: NmeaParser, data: VtgSentence.VTGData)
    func didParseDeviceData(_ sender: NmeaParser, data: String)
}

extension NmeaParserDelegate{
    func didParseRMCSentence(_ sender: NmeaParser, data: CLLocation){}
    func didParseGSASentence(_ sender: NmeaParser, data: GsaSentence.GSAData){}
    func didParseGSVSentence(_ sender: NmeaParser, data: GsvSentence.GSVData){}
    func didParseGLLSentence(_ sender: NmeaParser, data: GllSentence.GLLData){}
    func didParseGGASentence(_ sender: NmeaParser, data: GgaSentence.GGAData){}
    func didParseVTGSentence(_ sender: NmeaParser, data: VtgSentence.VTGData){}
    func didParseDeviceData(_ sender: NmeaParser, data: String){}
}
