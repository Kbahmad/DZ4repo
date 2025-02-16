import SwiftUI

struct AppUser: Codable, Identifiable {
    var id: Int
    var login: String
    var password: String?
    var email: String
    var token: String
}

struct CardModel: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var tags: [String]
}

struct OnboardingData: Identifiable {
    var id = UUID()
    var image: String
    var title: String
    var description: String
}

class AuthManager: ObservableObject {

    @Published var isAuthorized: Bool = false

    @Published var currentUser: AppUser? = nil

    let baseURL = "http://127.0.0.1:7000"

    @AppStorage("userToken") var userToken: String = ""

    init() {

        if !userToken.isEmpty {
            checkToken { [weak self] isValid in
                guard let self = self else { return }
                if isValid {

                    self.fetchUser { success in
                        self.isAuthorized = success
                    }
                } else {

                    self.logout()
                }
            }
        }
    }

    func logout() {
        userToken = ""
        currentUser = nil
        isAuthorized = false
    }

    func checkToken(completion: @escaping (Bool) -> Void) {
        guard !userToken.isEmpty else {
            completion(false)
            return
        }

        guard let url = URL(string: "\(baseURL)/api/auth/checkout") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil {
                completion(false)
                return
            }
            guard let httpResponse = resp as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            completion(true)
        }.resume()
    }

    func signIn(login: String, password: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/signin") else {
            completion(false, "Wrong URL.")
            return
        }

        let body: [String: Any] = ["login": login, "password": password]
        let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, resp, err in
            if let err = err {
                completion(false, err.localizedDescription)
                return
            }
            guard let data = data else {
                completion(false, "No data received.")
                return
            }

            guard let httpResponse = resp as? HTTPURLResponse else {
                completion(false, "Invalid response.")
                return
            }

            if httpResponse.statusCode == 200 {

                do {
                    let user = try JSONDecoder().decode(AppUser.self, from: data)
                    DispatchQueue.main.async {
                        self.currentUser = user
                        self.userToken = user.token
                        self.isAuthorized = true
                        completion(true, "")
                    }
                } catch {
                    completion(false, "Cannot decode user data.")
                }
            } else {

                if let json = try? JSONSerialization.jsonObject(with: data, options: []),
                   let dict = json as? [String: Any],
                   let msg = dict["message"] as? String {
                    completion(false, msg)
                } else {
                    completion(false, "Login error (status \(httpResponse.statusCode)).")
                }
            }
        }.resume()
    }

    func signUp(login: String, password: String, email: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/signup") else {
            completion(false, "Wrong URL.")
            return
        }
        let body: [String: Any] = ["login": login, "password": password, "email": email]
        let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, resp, err in
            if let err = err {
                completion(false, err.localizedDescription)
                return
            }
            guard let data = data else {
                completion(false, "No data received.")
                return
            }
            guard let httpResponse = resp as? HTTPURLResponse else {
                completion(false, "Invalid response.")
                return
            }

            if httpResponse.statusCode == 200 {

                do {
                    let user = try JSONDecoder().decode(AppUser.self, from: data)
                    DispatchQueue.main.async {
                        self.currentUser = user
                        self.userToken = user.token
                        self.isAuthorized = true
                        completion(true, "")
                    }
                } catch {
                    completion(false, "Cannot decode user data.")
                }
            } else {

                if let json = try? JSONSerialization.jsonObject(with: data, options: []),
                   let dict = json as? [String: Any],
                   let msg = dict["message"] as? String {
                    completion(false, msg)
                } else {
                    completion(false, "Sign up error (status \(httpResponse.statusCode)).")
                }
            }
        }.resume()
    }

    func fetchUser(completion: @escaping (Bool) -> Void) {
        guard !userToken.isEmpty,
              let url = URL(string: "\(baseURL)/api/auth/user") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil {
                completion(false)
                return
            }
            guard let data = data,
                  let httpResp = resp as? HTTPURLResponse,
                  httpResp.statusCode == 200 else {
                completion(false)
                return
            }

            do {
                let user = try JSONDecoder().decode(AppUser.self, from: data)
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isAuthorized = true
                    completion(true)
                }
            } catch {
                completion(false)
            }
        }.resume()
    }
}

struct Theme {
    var backgroundColor: Color
    var textColor: Color
    var buttonColor: Color
    var buttonTextColor: Color
}

struct Themes {
    static let light = Theme(
        backgroundColor: Color.white,
        textColor: Color.black,
        buttonColor: Color.blue,
        buttonTextColor: Color.white
    )

    static let dark = Theme(
        backgroundColor: Color.black,
        textColor: Color.white,
        buttonColor: Color.gray,
        buttonTextColor: Color.black
    )

    static let blue = Theme(
        backgroundColor: Color.blue,
        textColor: Color.blue,
        buttonColor: Color.blue,
        buttonTextColor: Color.white
    )

}

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedTheme: String = "light" {
        didSet { updateTheme() }
    }
    @Published var currentTheme: Theme = Themes.light

    init() {
        updateTheme()
    }

    func updateTheme() {
        DispatchQueue.main.async {
            self.objectWillChange.send() //  Ensures UI updates
            print("Selected Theme:", self.selectedTheme) // Debugging output
            switch self.selectedTheme {
            case "dark":
                self.currentTheme = Themes.dark
            case "blue":
                self.currentTheme = Themes.blue
            case "light":
                self.currentTheme = Themes.light
            default:
                self.selectedTheme = "light"
                self.currentTheme = Themes.light
            }
        }
    }

}

@main
struct DZ4App: App {
    @StateObject var authManager = AuthManager()
    @StateObject var themeManager = ThemeManager()

    @AppStorage("didCompleteOnboarding") var didCompleteOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !didCompleteOnboarding {

                    OnboardingRootView(didCompleteOnboarding: $didCompleteOnboarding)
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                } else if !authManager.isAuthorized {

                    AuthRootView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                } else {

                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                }
            }
            .environment(\.colorScheme, themeManager.selectedTheme == "dark" ? .dark : .light)
            .onAppear {
                themeManager.updateTheme()
            }

        }
    }
}

struct OnboardingRootView: View {
    @Binding var didCompleteOnboarding: Bool

    let pages = [
        OnboardingData(image: "img1", title: "Welcome", description: "Discover the app!"),
        OnboardingData(image: "img2", title: "Features", description: "Explore functionalities."),
        OnboardingData(image: "img3", title: "Get Started", description: "Let's begin!")
    ]

    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(pages.indices) { index in
                    VStack(spacing: 30) {
                        Image(pages[index].image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .padding()
                        Text(pages[index].title)
                            .font(.largeTitle)
                        Text(pages[index].description)
                            .font(.body)
                            .padding(.horizontal, 30)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }
                Spacer()
                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                } else {

                    Button("Finish") {
                        didCompleteOnboarding = true
                    }
                    .font(.headline)
                }
            }
            .padding()
        }
    }
}

struct AuthRootView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                Text("Kaiten\nДЗ №4").font(.title).multilineTextAlignment(.center)

                NavigationLink(destination: LoginView()) {
                    Text("Log In")
                        .font(.headline)
                        .frame(minWidth: 200, minHeight: 44)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                }

                NavigationLink(destination: RegistrationView()) {
                    Text("Sign Up")
                        .font(.headline)
                        .frame(minWidth: 200, minHeight: 44)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var login = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Login").font(.largeTitle)

            TextField("Username", text: $login)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                authManager.signIn(login: login, password: password) { success, msg in
                    if !success {
                        errorMessage = msg
                    }
                }
            }) {
                Text("Login")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 44)
                    .background(Color.blue)
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .navigationBarTitle("Login", displayMode: .inline)
    }
}

struct RegistrationView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var login = ""
    @State private var password = ""
    @State private var email = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign Up").font(.largeTitle)

            TextField("Username", text: $login)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5)

            TextField("Email", text: $email)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5)
                .keyboardType(.emailAddress)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                authManager.signUp(login: login, password: password, email: email) { success, msg in
                    if !success {
                        errorMessage = msg
                    }
                }
            }) {
                Text("Create Account")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 44)
                    .background(Color.green)
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .navigationBarTitle("Sign Up", displayMode: .inline)
    }
}

struct MainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        TabView {
            CardsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Cards")
                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
}

struct CardsView: View {
    @State private var cards = [
        CardModel(title: "Card 1", description: "Details for card 1", tags: ["Tag1", "Tag2"]),
        CardModel(title: "Card 2", description: "Details for card 2", tags: ["Tag3"])
    ]
    @State private var searchText = ""
    @State private var selectedTag: String = "All"
    @State private var showModal = false

    var allTags: [String] {

        let unique = Set(cards.flatMap { $0.tags })
        return Array(unique)
    }

    var filteredCards: [CardModel] {

        let byTag: [CardModel]
        if selectedTag == "All" {
            byTag = cards
        } else {
            byTag = cards.filter { $0.tags.contains(selectedTag) }
        }

        if searchText.isEmpty {
            return byTag
        } else {
            return byTag.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {

                Picker("Filter by Tag", selection: $selectedTag) {
                    Text("All").tag("All")
                    ForEach(allTags, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                TextField("Search", text: $searchText)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                List {
                    ForEach(filteredCards) { card in
                        CardView(card: card)
                            .onTapGesture {

                            }
                    }
                }
            }
            .navigationBarTitle("Cards")
            .navigationBarItems(trailing:
                Button(action: { showModal = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showModal) {
                AddCardView(cards: $cards)
            }
        }
    }
}

struct CardView: View {
    var card: CardModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.headline)
            Text(card.description)
                .font(.subheadline)
                .lineLimit(2)

            HStack {
                ForEach(card.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(5)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 3)
    }
}

struct AddCardView: View {
    @Binding var cards: [CardModel]
    @State private var title = ""
    @State private var description = ""
    @State private var tags = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Info")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Tags (comma separated)", text: $tags)
                }
                Button("Add Card") {
                    let tagList = tags.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    let newCard = CardModel(title: title, description: description, tags: tagList)
                    cards.append(newCard)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationBarTitle("Add Card", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                if let user = authManager.currentUser {
                    Text("Hello, \(user.login)").font(.largeTitle)
                    Text("Email: \(user.email)").font(.subheadline)
                } else {
                    Text("No user data").foregroundColor(.gray)
                }

                Button("Edit Profile") {
                    isEditing = true
                }
                .padding()
                .frame(width: 200, height: 44)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Spacer()
            }
            .sheet(isPresented: $isEditing) {
                EditProfileView()
            }
            .navigationBarTitle("Profile", displayMode: .inline)
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var login = ""
    @State private var email = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Login", text: $login)
                TextField("Email", text: $email).keyboardType(.emailAddress)
            }
            .navigationBarTitle("Edit Profile")
            .navigationBarItems(leading:
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }, trailing:
                Button("Save") {

                    if var user = authManager.currentUser {
                        user.login = login
                        user.email = email
                        authManager.currentUser = user
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                if let user = authManager.currentUser {
                    login = user.login
                    email = user.email
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager

    @State private var showFeedback = false
    @State private var showAbout = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Theme")) {
                    themeRow("Light", tag: "light")
                    themeRow("Dark", tag: "dark")
                    themeRow("Blue", tag: "blue")
                }

                Section(header: Text("Information")) {
                    Button("Feedback") {
                        showFeedback.toggle()
                    }
                    .sheet(isPresented: $showFeedback) {
                        NavigationView {
                            FeedbackView()
                        }
                    }

                    Button("About") {
                        showAbout.toggle()
                    }
                    .sheet(isPresented: $showAbout) {
                        NavigationView {
                            AboutView()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Text("Logout")
                    }
                    .alert(isPresented: $showLogoutAlert) {
                        Alert(
                            title: Text("Logout"),
                            message: Text("Are you sure you want to log out?"),
                            primaryButton: .destructive(Text("Logout")) {
                                authManager.logout()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func themeRow(_ title: String, tag: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            if themeManager.selectedTheme == tag {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            DispatchQueue.main.async {
                themeManager.selectedTheme = tag
                themeManager.updateTheme()
            }
        }
    }
}

struct FeedbackView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var feedbackText = ""

    var body: some View {
        VStack {
            Text("We value your feedback!")
                .font(.title)
                .padding()
            Text("Please let us know your thoughts and suggestions to improve the app.")
                .padding()
            TextEditor(text: $feedbackText)
                .border(Color.gray, width: 1)
                .padding()
            Button("Submit") {

                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            Spacer()
        }
        .navigationTitle("Feedback")
        .navigationBarItems(trailing:
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
}

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("About This App")
                .font(.title)
                .padding()
            Text("This is a sample app to demonstrate SwiftUI, JWT auth, and theming.")
                .padding()
            Text("Built for the НИС course project.")
                .padding()
            Spacer()
        }
        .navigationTitle("About")
        .navigationBarItems(trailing:
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
}






