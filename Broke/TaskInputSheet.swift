import SwiftUI

struct TaskInputSheet: View {
    // Environment objects or managers needed
    @EnvironmentObject var attendanceManager: AttendanceManager
    @EnvironmentObject var appBlocker: AppBlocker
    
    // Bindings or state passed from BrockerView
    @Binding var isPresented: Bool
    let recordIdToUpdate: UUID
    let profileToUse: Profile
    let onComplete: (String?) -> Void // Closure to call when done (passes task description)

    // Internal state for the sheet
    @State private var selectedTaskOption: String = "-- Select Task --"
    @State private var newTaskDescription: String = ""
    
    private let newTaskOptionString = "-- New Task --"
    private let selectTaskOptionString = "-- Select Task --"
    
    private var taskOptions: [String] {
        // Combine placeholder, existing tasks, and the new task option
        [selectTaskOptionString] + attendanceManager.uniqueTaskDescriptions + [newTaskOptionString]
    }
    
    private var isNewTaskSelected: Bool {
        selectedTaskOption == newTaskOptionString
    }

    var body: some View {
        NavigationView {
            Form {
                Picker("Select Task", selection: $selectedTaskOption) {
                    ForEach(taskOptions, id: \.self) { task in
                        Text(task)
                    }
                }
                
                if isNewTaskSelected {
                    TextField("Enter new task description", text: $newTaskDescription)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Button("Start Session") {
                    startSession()
                }
                .disabled(selectedTaskOption == selectTaskOptionString && !isNewTaskSelected) // Disable if no task selected/entered
            }
            .navigationTitle("Select Task")
            .navigationBarItems(leading: Button("Cancel") {
                 isPresented = false // Just dismiss
            })
            .animation(.default, value: selectedTaskOption) // Animate text field appearance
        }
    }
    
    private func startSession() {
        var finalTaskDescription: String?
        
        if isNewTaskSelected {
            if !newTaskDescription.isEmpty {
                finalTaskDescription = newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if selectedTaskOption != selectTaskOptionString {
            finalTaskDescription = selectedTaskOption
        }
        
        // Update the task in AttendanceManager
        if let task = finalTaskDescription {
             attendanceManager.updateTask(for: recordIdToUpdate, task: task)
        }
        
        // Call the completion handler (which will trigger blocking)
        onComplete(finalTaskDescription)
        
        // Dismiss the sheet
        isPresented = false
    }
}