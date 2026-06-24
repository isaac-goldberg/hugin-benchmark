//
//  ContentView.swift
//  hugin-benchmark
//
//  Created by Isaac Goldberg on 6/23/26.
//

import SwiftUI
import Combine
import Hugin

// MARK: - hugin engine wrapper
class HuginDecisionEngine: ObservableObject {
    @Published var outputLog: String = "Network uninitialized, click Compile Network to start."
    @Published var isCompiled: Bool = false
    
    private var domain: Domain?
    
    private var isRainingNode: Node?
    private var sprinklerOnNode: Node?
    private var grassWetNode: Node?

    func initializeNetwork() {
        do {
            let newLicense = try License(product: "Hugin Developer", user: "User 2", organization: "PiLogic", supportExpires: 20270623, key: "Ej1Pc-Q9q1D-RirUr-SKTQO-nhfb2-r4dbX-p21Ch-iones")
            
            let newDomain = try Domain(license:newLicense)
            self.domain = newDomain
            
            // isRaining node
            let rainNode = try newDomain.newNode(category: Node.Category.chance, kind: Node.Kind.discrete)
            try rainNode.setNumberOfStates(2)
            self.isRainingNode = rainNode
            
            // sprinklerOn node
            let sprinklerNode = try newDomain.newNode(category: Node.Category.chance, kind: Node.Kind.discrete)
            try sprinklerNode.setNumberOfStates(2)
            self.sprinklerOnNode = sprinklerNode
            
            // grassWet node
            let grassWetNode = try newDomain.newNode(category: Node.Category.chance, kind: Node.Kind.discrete)
            try grassWetNode.setNumberOfStates(2)
            self.grassWetNode = grassWetNode
            
            // link the nodes
            try sprinklerNode.addParent(rainNode)
            try grassWetNode.addParent(rainNode)
            try grassWetNode.addParent(sprinklerNode)
                        
            // PROBABILITY TABLES
            // note: 0th state corresponds to true, 1st state to false, to match the hugin GUI
            let rainTable = try rainNode.getTable()
            try rainTable.setDataItem(0, 0.2) // true
            try rainTable.setDataItem(1, 0.8) // false
            
            let sprinklerTable = try sprinklerNode.getTable()
            try sprinklerTable.setDataItem(0, 0.01)
            try sprinklerTable.setDataItem(1, 0.99)
            try sprinklerTable.setDataItem(2, 0.4)
            try sprinklerTable.setDataItem(3, 0.6)
            
            let grassWetTable = try grassWetNode.getTable()
            try grassWetTable.setDataItem(0, 0.99)
            try grassWetTable.setDataItem(1, 0.01)
            try grassWetTable.setDataItem(2, 0.9)
            try grassWetTable.setDataItem(3, 0.1)
            try grassWetTable.setDataItem(4, 0.8)
            try grassWetTable.setDataItem(5, 0.2)
            try grassWetTable.setDataItem(6, 0)
            try grassWetTable.setDataItem(7, 1)
            
            try newDomain.compile()
            isCompiled = true
            
            runInference(isRaining: nil, sprinklerOn: nil)
        } catch {
            outputLog = "error initializing network: \(error)"
        }
    }
    
    func runInference(isRaining: Bool?, sprinklerOn: Bool?) {
        guard let domain = domain, isCompiled else {
            outputLog = "network not compiled yet."
            return
        }
        
        do {
            try domain.retractFindings()
            
            if let isRaining = isRaining {
                try isRainingNode?.selectState(isRaining ? 0 : 1)
            }
            if let sprinklerOn = sprinklerOn {
                try sprinklerOnNode?.selectState(sprinklerOn ? 0 : 1)
            }
            
            try domain.propagate()
            
            let probIsRainingTrue = try isRainingNode?.getBelief(0) ?? 0.0
            let probIsRainingFalse = try isRainingNode?.getBelief(1) ?? 0.0
            
            let probGrassWetTrue = try grassWetNode?.getBelief(0) ?? 0.0
            let probGrassWetFalse = try grassWetNode?.getBelief(1) ?? 0.0
            
            let probSprinklerTrue = try sprinklerOnNode?.getBelief(0) ?? 0.0
            let probSprinklerFalse = try sprinklerOnNode?.getBelief(1) ?? 0.0
            
            outputLog = "Evidence:\n"
            
            if let isRaining = isRaining {
                outputLog += "IsRaining = \(isRaining ? "true" : "false")\n"
            }
            
            if let sprinklerOn = sprinklerOn {
                outputLog += "SprinklerOn = \(sprinklerOn ? "true" : "false")\n"
            }
            
            if (isRaining == nil && sprinklerOn == nil) {
                outputLog += "No evidence yet\n"
            }
            
            outputLog += "\nCalculated Probabilities\n"
            outputLog += String(format: "IsRaining:\n true:  %.2f%\n false: %.2f%\n\n", probIsRainingTrue * 100, probIsRainingFalse * 100)
            outputLog += String(format: "SprinklerOn:\n true:  %.2f%\n false: %.2f%\n\n", probSprinklerTrue * 100, probSprinklerFalse * 100)
            outputLog += String(format: "GrassWet:\n  true:  %.2f%\n  false: %.2f%\n", probGrassWetTrue * 100, probGrassWetFalse * 100)
            
        } catch {
            outputLog = "Inference error: \(error)"
        }
    }
}

// MARK: - button component
struct InferenceButton: View {
    let title: String
    let isEnabled: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .background(isEnabled ? (isSelected ? Color.blue : Color.black) : Color.black)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!isEnabled)
    }
}

// MARK: - main UI view
struct ContentView: View {
    @StateObject private var engine = HuginDecisionEngine()
    @State private var selectedRain: Bool? = nil
    @State private var selectedSprinkler: Bool? = nil
    
    private func updateInference() {
        engine.runInference(isRaining: selectedRain, sprinklerOn: selectedSprinkler)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Text("Hugin Test UI")
                    .font(.title2)
                    .fontWeight(.bold)
                
                ScrollView {
                    Text(engine.outputLog)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
                .frame(height: 250)
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    InferenceButton(
                        title: "Compile Network",
                        isEnabled: true,
                        isSelected: false,
                        action: {
                            engine.initializeNetwork()
                        }
                    )
                    
                    VStack(spacing: 12) {
                        Text("Weather:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            InferenceButton(
                                title: "No Rain",
                                isEnabled: engine.isCompiled,
                                isSelected: selectedRain == false,
                                action: {
                                    if (selectedRain == false) {
                                        selectedRain = nil
                                    } else {
                                        selectedRain = false
                                    }
                                    updateInference()
                                }
                            )
                            
                            InferenceButton(
                                title: "Rain",
                                isEnabled: engine.isCompiled,
                                isSelected: selectedRain == true,
                                action: {
                                    if (selectedRain == true) {
                                        selectedRain = nil
                                    } else {
                                        selectedRain = true
                                    }
                                    updateInference()
                                }
                            )
                        }
                        
                        Text("Sprinkler:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            InferenceButton(
                                title: "Sprinkler Off",
                                isEnabled: engine.isCompiled,
                                isSelected: selectedSprinkler == false,
                                action: {
                                    if (selectedSprinkler == false) {
                                        selectedSprinkler = nil
                                    } else {
                                        selectedSprinkler = false
                                    }
                                    updateInference()
                                }
                            )
                            
                            InferenceButton(
                                title: "Sprinkler On",
                                isEnabled: engine.isCompiled,
                                isSelected: selectedSprinkler == true,
                                action: {
                                    if (selectedSprinkler == true) {
                                        selectedSprinkler = nil
                                    } else {
                                        selectedSprinkler = true
                                    }
                                    updateInference()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Hugin Testing")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 500, height: 900)
    }
}
