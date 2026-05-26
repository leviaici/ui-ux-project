import SwiftUI

struct MainView: View {
    @StateObject var viewModel = MainViewViewModel()
    @EnvironmentObject var locationManager: LocationManager // Access LocationManager
    
    var body: some View {
        if viewModel.isSignedIn, !viewModel.currentUserId.isEmpty {
            accountView
                .onAppear {
                    printLocationCoordinates() // Print coordinates when the view appears
                }
        } else {
            LoginView()
        }
    }
    
    @ViewBuilder
    var accountView: some View {
        TabView {
            ItemsView(userId: viewModel.currentUserId)
                .tabItem{
                    Label("Home", systemImage: "house")
                }
            
            CalendarView(userId: viewModel.currentUserId)
                .tabItem{
                    Label("Calendar", systemImage: "calendar")
                }
            
            WeeklySummaryView(userId: viewModel.currentUserId)
                .tabItem{
                    Label("Summary", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            LLMView(userId: viewModel.currentUserId)
                .tabItem{
                    Label("Tomorrow", systemImage: "lightbulb.min.fill")
                }
            
            ProfileView()
                .tabItem{
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
    
    // Function to print the location coordinates to the console
    func printLocationCoordinates() {
        if let location = locationManager.location {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            print("User's Location - Latitude: \(latitude), Longitude: \(longitude)")
        } else {
            print("Location is not available yet")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
