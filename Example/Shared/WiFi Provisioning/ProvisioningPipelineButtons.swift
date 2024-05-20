//
//  ProvisioningPipelineButtons.swift
//  nRF-Wi-Fi-Provisioner (iOS)
//
//  Created by Dinesh Harjani on 17/5/24.
//

import SwiftUI

// MARK: - ProvisioningPipelineButtons

struct ProvisioningPipelineButtons: View {
    
    // MARK: Private Properties
    
    @EnvironmentObject private var viewModel: ProvisionOverWiFiView.ViewModel
    
    let onRetry: () -> Void
    let onSuccess: () -> Void
    
    // MARK: View
    
    var body: some View {
        HStack {
            if viewModel.pipelineManager.inProgress {
                ProgressView()
            } else {
                if viewModel.pipelineManager.isCompleted(.provision) {
                    Button(action: onSuccess) {
                        Label("Success!", systemImage: "fireworks")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Retry", action: onRetry)
                    .tint(.nordicRed)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
