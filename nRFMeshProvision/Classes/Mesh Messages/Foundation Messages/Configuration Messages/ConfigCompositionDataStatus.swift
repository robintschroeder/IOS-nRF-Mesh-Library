//
//  ConfigCompositionDataStatus.swift
//  nRFMeshProvision
//
//  Created by Aleksander Nowakowski on 14/06/2019.
//

import Foundation

public protocol CompositionDataPage {
    /// Page number of the Composition Data to get.
    var page: UInt8 { get }
    /// Composition Data parameters as Data.
    var parameters: Data? { get }
}

public struct ConfigCompositionDataStatus: ConfigMessage {
    public let opCode: UInt32 = 0x02
    public var parameters: Data? {
        return page?.parameters
    }
    
    /// The Composition Data page.
    public let page: CompositionDataPage?
    
    public init?(parameters: Data) {
        guard parameters.count > 0 else {
            return nil
        }
        switch parameters[0] {
        case 0:
            guard let page0 = Page0(parameters: parameters) else {
                return nil
            }
            page = page0
        default:
            // Other Pages are not supoprted.
            return nil
        }
    }
}

public struct Page0: CompositionDataPage {
    /// Page number of the Composition Data to get.
    public let page: UInt8
    
    /// The 16-bit Company Identifier (CID) assigned by the Bluetooth SIG.
    /// The value of this property is obtained from node composition data.
    public let companyIdentifier: UInt16
    /// The 16-bit vendor-assigned Product Identifier (PID).
    /// The value of this property is obtained from node composition data.
    public let productIdentifier: UInt16
    /// The 16-bit vendor-assigned Version Identifier (VID).
    /// The value of this property is obtained from node composition data.
    public let versionIdentifier: UInt16
    /// The minimum number of Replay Protection List (RPL) entries for this
    /// node. The value of this property is obtained from node composition
    /// data.
    public let minimumNumberOfReplayProtectionList: UInt16
    /// Node's features. See `NodeFeatures` for details.
    public let features: NodeFeatures
    /// An array of node's elements.
    public let elements: [Element]
    
    public var parameters: Data? {
        return Data([page])
            + companyIdentifier + productIdentifier + versionIdentifier
            + minimumNumberOfReplayProtectionList
            + features.rawValue + elements.data
    }
    
    public var isSegmented: Bool {
        return true
    }
    
    /// This initializer constructs the Page 0 of Composition Data from
    /// the given Node.
    ///
    /// - parameter node: The Node to construct the Page 0 from.
    public init(node: Node) {
        page = 0
        companyIdentifier = node.companyIdentifier ?? 0
        productIdentifier = node.productIdentifier ?? 0
        versionIdentifier = node.versionIdentifier ?? 0
        minimumNumberOfReplayProtectionList = node.minimumNumberOfReplayProtectionList ?? 0
        features = node.features ?? NodeFeatures()
        elements = node.elements
    }
    
    /// This initializer should construct the message based on the
    /// received parameters.
    ///
    /// - parameter parameters: The Access Layer parameters.
    public init?(parameters: Data) {
        guard parameters.count >= 11, parameters[0] == 0 else {
            return nil
        }
        page = 0
        companyIdentifier = CFSwapInt16LittleToHost(parameters.convert(offset: 1))
        productIdentifier = CFSwapInt16LittleToHost(parameters.convert(offset: 3))
        versionIdentifier = CFSwapInt16LittleToHost(parameters.convert(offset: 5))
        minimumNumberOfReplayProtectionList = CFSwapInt16LittleToHost(parameters.convert(offset: 7))
        features = NodeFeatures(rawValue: CFSwapInt16LittleToHost(parameters.convert(offset: 9)))
        
        var readElements: [Element] = []
        var offset = 11
        while offset < parameters.count {
            guard let element = Element(compositionData: parameters, offset: &offset) else {
                return nil
            }
            element.index = UInt8(readElements.count)
            readElements.append(element)
        }
        elements = readElements
    }
    
    /// Applies the Composition Data to given Node.
    ///
    /// - parameter node: The Node to apply the data to.
    public func apply(to node: Node) {
        node.companyIdentifier = companyIdentifier
        node.productIdentifier = productIdentifier
        node.versionIdentifier = versionIdentifier
        node.minimumNumberOfReplayProtectionList = minimumNumberOfReplayProtectionList
        node.features = features
        // Remove any existing Elements. There should not be any, but just to be sure.
        node.elements.forEach {
            $0.parentNode = nil
            $0.index = 0
        }
        node.elements.removeAll()
        // And add the Elements received.
        node.add(elements: elements)
    }
}

// MARK: - Helper extension

private typealias El = Element
private extension Array where Element == El {
    
    /// Returns Elements and their Models as Data, to be sent in
    /// Page 0 of the Composition Data.
    var data: Data {
        var data = Data()
        for element in self {
            data += element.location.rawValue
            
            var sigModels: [Model] = []
            var vendorModel: [Model] = []
            for model in element.models {
                if model.isBluetoothSIGAssigned {
                    sigModels.append(model)
                } else {
                    vendorModel.append(model)
                }
            }
            data += UInt8(sigModels.count)
            data += UInt8(vendorModel.count)
            
            for model in sigModels {
                data += model.modelIdentifier
            }
            for model in vendorModel {
                data += model.modelId
            }
        }
        return data
    }
    
}
