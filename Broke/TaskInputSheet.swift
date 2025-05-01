/**
 * A SwiftUI view presented as a sheet for selecting a task category.
 *
 * This view allows the user to choose a `TaskCategory` for an existing,
 * active attendance record. Upon selection and confirmation, it updates
 * the record via the `AttendanceManager` and calls a completion handler.
 * It requires bindings and environment objects to interact with the parent view
 * and necessary managers (`AttendanceManager`, `AppBlocker`).
 */

import SwiftUI

struct TaskInputSheet: View {
    // Environment objects or managers needed
    @EnvironmentObject var attendanceManager: AttendanceManager
    @EnvironmentObject var appBlocker: AppBlocker
    
    // Bindings or state passed from BrockerView
    @Binding var isPresented: Bool
    let recordIdToUpdate: UUID
    let profileToUse: Profile
    let onComplete: (String?) -> Void // Closure to call when done (passes task description string)

    // Internal state for the sheet
    @State private var selectedTaskCategory: TaskCategory? = nil // Changed type, default nil

    var body: some View {
        NavigationView {
            Form {
                // Picker using TaskCategory
                Picker("Select Task", selection: $selectedTaskCategory) {
                    Text("-- Select Task --").tag(nil as TaskCategory?) // Add a nil option
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.rawValue).tag(category as TaskCategory?)
                    }
                }
                
                Button("Start Session") {
                    startSession()
                }
                .disabled(selectedTaskCategory == nil) // Disable if no category selected
            }
            .navigationTitle("Select Task")
            .navigationBarItems(leading: Button("Cancel") {
                 isPresented = false // Just dismiss
            })
        }
    }
    
    private func startSession() {
         // Check if a category was selected
         guard let category = selectedTaskCategory else {
             print("No task category selected.") 
             // If no category is selected, maybe treat as "Other" or just proceed without task?
             // Let's call onComplete with nil for now, indicating no specific task chosen.
             onComplete(nil) 
             isPresented = false
             return
         }
        
        // Update the task category in AttendanceManager
        attendanceManager.updateTaskCategory(for: recordIdToUpdate, category: category)
        
        // Call the completion handler (passing the selected category's rawValue for the message)
        onComplete(category.rawValue)
        
        // Dismiss the sheet
        isPresented = false
    }
}