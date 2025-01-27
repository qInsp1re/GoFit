import SwiftUI
import MapKit
import RealmSwift
import Foundation
import CommonCrypto
import CoreLocation
import HealthKit
import WidgetKit
import RealmSwift
import Foundation
import CoreLocation
import PhotosUI
import UserNotifications

class NotificationManager {
    
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Разрешение получено")
            } else {
                print("Разрешение не получено")
            }
        }
    }
    
    // Планирование уведомлений
    func scheduleNotifications() {
        let messages = ["Пора тренироваться!", "Не забудьте про правильное питание!", "Может, еще одну тренировочку?"]
        let hours = [10, 13, 17] // Указываем часы для уведомлений
        
        for i in 0..<messages.count {
            let content = UNMutableNotificationContent()
            content.title = "Go Fit"
            content.body = messages[i]
            content.sound = UNNotificationSound.default

            var dateComponents = DateComponents()
            dateComponents.hour = hours[i]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Ошибка при добавлении уведомления: \(error.localizedDescription)")
                }
            }
        }
    }
}

class RealmManager {
    static let shared = RealmManager()

    private init() {
        setupRealm()
    }

    private func setupRealm() {
        let app = App(id: "gofit-yhduk") // ID вашего приложения Realm

        // Проверка, что пользователь уже вошёл в систему
        guard UserDefaults.standard.bool(forKey: "isUserLoggedIn"),
              let userId = UserDefaults.standard.string(forKey: "currentUserID"),
              let user = app.currentUser else {
            print("Пользователь не авторизован или не найден")
            return
        }

        let partitionValue = "user=\(userId)" // Используйте ID пользователя как partitionValue

        var config = user.configuration(partitionValue: partitionValue)
        config.schemaVersion = 3
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 3 {
                migration.enumerateObjects(ofType: User.className()) { _, newObject in
                    newObject?["goPoints"] = 0
                }
            }
        }

        Realm.Configuration.defaultConfiguration = config
    }

    func getRealm() throws -> Realm {
        return try Realm()
    }
}



extension String {
    func sha256() -> String {
        if let data = self.data(using: .utf8) {
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
}

struct SplashScreen: View {
    @State private var isActive = false
    @State private var isProUser: Bool = false // Это временная заглушка. Вам нужно получить реальное значение из вашей логики подписки.

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)  // Setting black background for the entire screen

            VStack {
                if isActive {
                    ContentView()
                } else {
                    VStack {
                        Image("logo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 300, height: 300)
                            .padding()
                        
                        if isProUser {
                            Text("Pro")
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue)
                                .cornerRadius(15)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isActive = true
                }
            }
        }
    }
}




class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    
    func load(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let downloadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
}

struct RemoteImage: View {
    @StateObject private var loader = ImageLoader()
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loader.load(from: url)
        }
    }
}



class User: Object {
    @objc dynamic var id: String = UUID().uuidString
    @objc dynamic var username: String = ""
    @objc dynamic var email: String = ""
    @objc dynamic var password: String = ""
    @objc dynamic var eventsCount: Int = 0
    @objc dynamic var goPoints: Int = 0
    @objc dynamic var isProUser: Bool = false
    @objc dynamic var profilePicture: Data? = nil

    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    func setPassword(_ password: String) {
        self.password = password
    }
    
    func validatePassword(_ inputPassword: String) -> Bool {
        return self.password == inputPassword
    }
}

struct RegisterView: View {
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var isImagePickerShowing = false
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                            self.isImagePickerShowing = true
                        }) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            }
                        }
                        .sheet(isPresented: $isImagePickerShowing) {
                            ImagePicker(image: $profileImage)
                        }
            TextField("Имя пользователя", text: $username)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(15)

                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(15)

                        SecureField("Пароль", text: $password)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(15)

                        // Кнопка регистрации
                        Button(action: register) {
                            Text("Регистрация")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                    }
                    .padding()
                    .navigationTitle("Регистрация")
                }

    func register() {
        let user = User()
        user.username = username
        user.email = email
        user.setPassword(password)
        if let profileImage = profileImage {
                    user.profilePicture = profileImage.jpegData(compressionQuality: 0.8) // Конвертируем изображение в Data
                }
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(user)
            }
            UserDefaults.standard.setValue(user.id, forKey: "currentUserID")
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Ошибка при сохранении пользователя: \(error)")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.mode.wrappedValue.dismiss()
        }
    }
}
struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @Binding var isLoggedIn: Bool
    @State private var showingRegister = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    // Логотип и описание
                    Image("logo") // Замените на имя вашего файла изображения логотипа
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)

                    Text("Go Fit - ваша персональная спортивная экосистема.")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Поля ввода
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)

                    SecureField("Пароль", text: $password)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)

                    // Кнопка входа
                    Button(action: login) {
                        Text("Войти")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }

                    // Ссылка на регистрацию
                    NavigationLink(destination: RegisterView(), isActive: $showingRegister) {
                        Text("Зарегистрироваться")
                    }
                    .onTapGesture {
                        showingRegister = true
                    }
                }
                .padding()
                .navigationBarHidden(true)
            }
        }

    func login() {
        do {
            let realm = try Realm()
            if let user = realm.objects(User.self).filter("email == %@", email).first, user.validatePassword(password) {
                UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
                UserDefaults.standard.setValue(user.id, forKey: "currentUserID") // добавьте эту строку
                isLoggedIn = true
                presentationMode.wrappedValue.dismiss()
            } else {
                // Можете добавить сообщение об ошибке или анимацию, сообщающую о неправильных учетных данных
            }
        } catch {
            print("Ошибка при попытке войти: \(error)")
        }
    }


}




struct SportPlace: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let imageUrl: URL
    let sports: String
    let cost: String
    let workingHours: String
    let hasToilet: Bool
    let hasChangingRoom: Bool
    let hasShower: Bool
    let coordinate: CLLocationCoordinate2D
}
struct Place: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
}




struct NewsItem: Identifiable {
    var id = UUID()
    let title: String
    let description: String
    var imageUrl: URL
}
struct TrainingRecommendation: Identifiable {
    var id = UUID()
    let title: String
    let exercises: [Exercise]
    var imageUrl: URL
}

struct Exercise {
    let name: String
}



struct SportPlacesView: View {
    
    
    var allPlaces: [SportPlace] = [
        SportPlace(name: "Парк Гагарина",
                   address: "Самара, Парк имени Юрия Гагарина",
                   imageUrl: URL(string: "https://parki-samara.ru/wp-content/uploads/5003.jpg")!,
                   sports: "Футбол, бег, баскетбол, волейбол, тренажеры, йога",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.226692, longitude: 50.198147)        ),
        SportPlace(name: "На набережной Волги",
                   address: "Самара, Волжский проспект 36",
                   imageUrl: URL(string: "https://sgpress.ru/wp-content/uploads/2023/08/986A2419-442C-44E7-A569-226D7DB6D55B.jpeg")!,
                   sports: "Йога, бег, велосипед, тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.208192, longitude: 50.114450)
        ),
        SportPlace(name: "Струковский скейт парк",
                   address: "Самара, Струковский сад",
                   imageUrl: URL(string: "https://avatars.mds.yandex.net/get-altay/4546519/2a000001821b1acc85d42163051364c95ee1/XXXL")!,
                   sports: "Футбол, бег, баскетбол, волейбол, тренажеры, йога",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.197674, longitude: 50.094031)
                  ),
        SportPlace(name: "На стадионе Динамо",
                   address: "Самара, ул. Льва Толстого, 97А",
                   imageUrl: URL(string: "https://lh3.googleusercontent.com/p/AF1QipMK4VE1zIobzKnEqvUEye4f-G2yMLjGQ9ahteTq=s1360-w1360-h1020")!,
                   sports: "Футбол, бег, тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: true,
                   coordinate: CLLocationCoordinate2D(latitude: 53.188237, longitude: 50.108137)
                  ),
        SportPlace(name: "На старой набережной",
                   address: "Самара, Струковский сад",
                   imageUrl: URL(string: "https://avatars.mds.yandex.net/get-altay/4546519/2a000001821b1acc85d42163051364c95ee1/XXXL")!,
                   sports: "Футбол, бег, тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.188481, longitude: 50.080386)
                  ),
        SportPlace(name: "Теннисный корт Самара Ланд",
                   address: "Самара, Демократическая 45А",
                   imageUrl: URL(string: "https://samara-tennis.ru/upload/iblock/da7/da72ea2dcaeef48748429491c41e3891.jpg")!,
                   sports: "Теннис",
                   cost: "1200 руб/час",
                   workingHours: "08:00 - 00:00",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: true,
                   coordinate: CLLocationCoordinate2D(latitude: 53.273377, longitude: 50.226532)
                  ),
        SportPlace(name: "Теннисный корт Загородный парк",
                   address: "Самара, Ново-Садовая 160",
                   imageUrl: URL(string: "https://samara-tennis.ru/upload/iblock/522/5228166ce389ac2717df67c8a9ae16c4.jpg")!,
                   sports: "Теннис",
                   cost: "800 руб/час",
                   workingHours: "08:00 - 00:00",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: true,
                   coordinate: CLLocationCoordinate2D(latitude: 53.230374, longitude: 50.177718)
                  ),
        SportPlace(name: "Теннисный корт Тригон",
                   address: "Самара, Дачная 4А",
                   imageUrl: URL(string: "https://www.trigon-tennis.ru/upload/iblock/cee/ceeb659611b8b688bb83e3696aff574f.jpg")!,
                   sports: "Теннис",
                   cost: "1100 руб/час",
                   workingHours: "06:00 - 00:00",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: true,
                   coordinate: CLLocationCoordinate2D(latitude: 53.200566, longitude: 50.143609)
                  ),
        SportPlace(name: "Площадка на Мечникова",
                   address: "Самара, ЖК на Мечникова",
                   imageUrl: URL(string: "https://iq.cdnstroy.ru/qn7ly82du1d2k_je4ib3.png")!,
                   sports: "Баскетбол, тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: false,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.186513, longitude:  50.135614)
                  ),
        SportPlace(name: "Площадка аллея Маршалов",
                   address: "Самара, Аллея Маршалов",
                   imageUrl: URL(string: "https://www.494unr.ru/images/content/news/2018-07-20_3.jpg")!,
                   sports: "Тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: false,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.204334, longitude:  50.112738 )
                  ),
        SportPlace(name: "В сквере Мичурина",
                   address: "Самара, сквер Мичурина",
                   imageUrl: URL(string: "https://avatars.mds.yandex.net/get-altay/2022045/2a00000173f5364b2876db3505441740dab6/orig")!,
                   sports: "Футбол, тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.199310, longitude:  50.129712)
                  ),
        SportPlace(name: "Площадка на Коммунистической",
                   address: "Самара, Коммунистическая 12",
                   imageUrl: URL(string: "https://avatars.mds.yandex.net/get-altay/4012790/2a0000018233ce85590948d003cb9452ce80/orig")!,
                   sports: "Тренажеры",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: false,
                   hasChangingRoom: false,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.199034, longitude:  50.135928)
                  ),
        SportPlace(name: "Площадка СГАУ",
                   address: "Самара, Лукачева",
                   imageUrl: URL(string: "https://avatars.mds.yandex.net/get-altay/3717246/2a00000179f451c496fcfbb46c69f717bd20/orig")!,
                   sports: "Тренажеры, футбол, баскетбол, волейбол",
                   cost: "Бесплатно",
                   workingHours: "Круглосуточно",
                   hasToilet: true,
                   hasChangingRoom: true,
                   hasShower: false,
                   coordinate: CLLocationCoordinate2D(latitude: 53.213805, longitude:  50.173909)
                  ),
    ]
    @State private var showMap = false
    @State private var filteredPlaces: [SportPlace]
    @State private var showFilterSheet = false
        @State private var selectedSport = "Все"
    @State private var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.2415, longitude: 50.2212),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    init() {
            _filteredPlaces = State(initialValue: allPlaces)
        }
    func applyFilter(sport: String) {
            if sport == "Все" {
                filteredPlaces = allPlaces
            } else {
                filteredPlaces = allPlaces.filter { $0.sports.contains(sport) }
            }
        }

        func getAllSports() -> [String] {
            var sports = Set<String>()
            for place in allPlaces {
                sports.formUnion(place.sports.components(separatedBy: ", "))
            }
            return ["Все"] + sports.sorted()
        }
    var body: some View {
            NavigationView {
                List(filteredPlaces) { place in
                    VStack(alignment: .leading) {
                        Text(place.name).font(.headline)
                        RemoteImage(url: place.imageUrl)
                            .frame(height: 200)
                            .cornerRadius(8)
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(place.address)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "sportscourt")
                            Text(place.sports)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle")
                            Text(place.cost)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(place.workingHours)
                        }
                        if place.hasToilet {
                            HStack(spacing: 4) {
                                Image(systemName: "toilet")
                                Text("Туалет")
                            }
                        }
                        if place.hasChangingRoom {
                            HStack(spacing: 4) {
                                Image(systemName: "square.split.2x1")
                                Text("Раздевалка")
                            }
                        }
                        if place.hasShower {
                            HStack(spacing: 4) {
                                Image(systemName: "shower")
                                Text("Душ")
                            }
                        }
                    }
                }
                .navigationBarTitle("Спортплощадки", displayMode: .inline)
                .navigationBarItems(trailing:
                                HStack {
                                    Button(action: {
                                        self.showFilterSheet = true
                                    }) {
                                        Image(systemName: "line.horizontal.3.decrease.circle")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    }
                                    .sheet(isPresented: $showFilterSheet) {
                                        FilterView(selectedSport: $selectedSport, allSports: getAllSports(), onFilterSelect: applyFilter)
                                    }
                                    
                                    Button(action: {
                                        self.showMap.toggle()
                                    }) {
                                        Image(systemName: "map")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    }
                                    .sheet(isPresented: $showMap) {
                                        SportPlacesMapView(places: allPlaces)
                                    }
                                }
                            )
            }
        }
    }

struct FilterView: View {
    @Binding var selectedSport: String
    var allSports: [String]
    var onFilterSelect: (String) -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(allSports, id: \.self) { sport in
                Button(action: {
                    self.selectedSport = sport
                    onFilterSelect(sport)
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text(sport)
                }
            }
            .navigationBarTitle("Выберите вид спорта", displayMode: .inline)
        }
    }
}

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private var locationManager = CLLocationManager()
    @Published var location: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // Функция для запроса разрешения на использование геолокации
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // Начать обновление местоположения
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    func getCurrentUserAnnotation() -> UserAnnotation? {
           guard let currentLocation = location else { return nil }
           return UserAnnotation(coordinate: currentLocation.coordinate)
       }
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // После получения разрешения начинаем обновление местоположения
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Доступ к местоположению отклонен или ограничен.")
        case .notDetermined:
            print("Статус авторизации еще не определен.")
        @unknown default:
            print("Неизвестный статус авторизации.")
        }
    }
}





struct UserAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct SportPlacesMapView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlace: SportPlace?
    var places: [SportPlace]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.2415, longitude: 50.2212),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: places) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    Button(action: {
                        selectedPlace = place
                    }) {
                        Image(systemName: "sportscourt")
                            .tint(.blue)
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white))
                            .shadow(radius: 3)
                            
                    }
                }
            }
            .overlay(
                placeDetailView(place: selectedPlace),
                alignment: .bottom
            )
            .navigationBarTitle("Карта", displayMode: .inline)
            .navigationBarItems(leading: Button("Назад") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    @ViewBuilder
    private func placeDetailView(place: SportPlace?) -> some View {
        if let place = place {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .center, spacing: 4) { // Изменили на .center для выравнивания текста по центру
                        Text(place.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(place.address)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity) // Растягиваем текст на максимальную ширину

                    Spacer() // Располагаем пространство между текстом и кнопкой

                    Button(action: {
                        // Действие для закрытия всплывающего меню
                        self.selectedPlace = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20) // Выравнивание с остальным контентом
                .padding(.top, 5) // Дополнительный padding сверху

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        RemoteImage(url: place.imageUrl)
                            .frame(width: 100, height: 100) // Увеличили картинку
                            .cornerRadius(8)

                        Button(action: {
                            openInMaps(place: place)
                        }) {
                            HStack {
                                Image(systemName: "map") // Добавляем иконку карты
                                    .foregroundColor(.white)
                                Text("Маршрут")
                                    .foregroundColor(.white)
                            }
                            .frame(height: 20) // Высота кнопки
                            .frame(maxWidth: .infinity) // Растягиваем кнопку на всю ширину
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .frame(width: 120) // Увеличили ширину левой колонки

                    VStack(alignment: .leading, spacing: 4) {
                        if place.sports.contains("Футбол") {
                            Label("Футбол", systemImage: "sportscourt.fill")
                        }
                        if place.sports.contains("Бег") {
                            Label("Бег", systemImage: "figure.run")
                        }
                        if place.sports.contains("Баскетбол") {
                            Label("Баскетбол", systemImage: "basketball")
                        }
                        if place.sports.contains("Волейбол") {
                            Label("Волейбол", systemImage: "sportscourt")
                        }
                        if place.cost != "" {
                            Label(place.cost, systemImage: "dollarsign.circle")
                        }
                        if place.workingHours != "" {
                            Label(place.workingHours, systemImage: "clock")
                        }
                        if place.hasToilet {
                            Label("Туалет", systemImage: "toilet")
                        }
                        if place.hasChangingRoom {
                            Label("Раздевалка", systemImage: "rectangle.3.offgrid")
                        }
                        if place.hasShower {
                            Label("Душ", systemImage: "shower")
                        }
                    }
                }
            }
            .padding(.vertical, 20) // Увеличенный вертикальный padding для большей высоты меню
            .padding(.horizontal, 20) // Существующий горизонтальный padding
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 5)
            .frame(maxWidth: .infinity) // Растягиваем на весь экран
            .edgesIgnoringSafeArea(.horizontal)
        }
    }



    private func openInMaps(place: SportPlace) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        destination.name = place.name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}


struct MapView: View {
    @Binding var region: MKCoordinateRegion
    var places: [Place]

    var body: some View {
        Map {
            ForEach(places) { place in
                Annotation("a" ,coordinate: place.coordinate) {
                    Image(systemName: "sportscourt")
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white))
                        .shadow(radius: 3)
                }
            }
        }
    }
}






class IdentifiablePointAnnotation: MKPointAnnotation, Identifiable {
    let id = UUID()
}

struct HealthDetail: Identifiable {
    var id = UUID()
    var title: String
    var value: Double
    var unit: String
    var color: Color?
    var sfSymbol: String?
    var maxValue: Double

}


struct HealthDetailView: View {
    var detail: HealthDetail

    var body: some View {
        VStack {
            if let sfSymbol = detail.sfSymbol {
                Image(systemName: sfSymbol)
                    .font(.largeTitle)
                    .foregroundColor(detail.color)
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat((Float(detail.value) ) / Float(detail.maxValue)))
                    .stroke(detail.color ?? Color.gray, lineWidth: 10)
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0))
            }
            Text("\(Int(detail.value)) \(detail.unit)")
                .font(.title2)
                .foregroundColor(detail.color)
            Text(detail.title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}


struct TrainingRecommendationsView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject var eventsViewModel = EventsViewModel() // Создаем экземпляр ViewModel
    @State private var activeEnergy: Double = 0.0
        @State private var steps: Double = 0.0
        @State private var sleepAnalysis: Double = 0.0
        @State private var averageHeartRate: Double = 0.0
        @State private var exerciseMinutes: Double = 0.0
        @State private var weight: Double = 0.0

    var recommendations: [TrainingRecommendation] = [
        TrainingRecommendation(title: "Разминка", exercises: [Exercise(name: "Инструкция по разминке\n\n\n1. Стойка на месте (1-2 минуты)\n- Стоя прямо, начните шагать на месте.\n- Поднимайте колени высоко, чтобы они были на уровне талии или выше.\n- Машите руками в ритме шагов.\n\n2. Вращение плеч (1 минута)\n- Стоя прямо, разведите руки в стороны на уровне плеч.\n- Сделайте большие круги руками вперед и назад.\n\n3. Вращение тазом (1 минута)\n- Разведите ноги на ширину плеч и руки положите на бока.\n- Делайте вращательные движения тазом в одну и другую сторону.\n\n4. Вращение головой (30 секунд)\n- Стоя прямо, медленно поворачивайте голову влево и вправо, а затем вверх и вниз.\n- Избегайте полного кругового вращения.\n\n5. Вытягивание квадрицепса (30 секунд на каждую ногу)\n- Встаньте прямо и, держась за стул или стену, согните одну ногу, держа стопу рукой у ягодиц.\n- Почувствуйте растяжение в передней части бедра. Повторите с другой ногой.\n\n6. Наклоны (1 минута)\n- Разведите ноги шире плеч и медленно наклоняйтесь вперед, пытаясь дотянуться до пола.\n- Возвращайтесь в исходное положение и наклоняйтесь влево и вправо, держа спину прямо.\n\n7. Приседания (1 минута)\n- Разведите ноги на ширину плеч, руки вытяните вперед.\n- Приседайте, как будто садитесь на стул, держите спину прямо.\n\n8. Разминка голеностопов (30 секунд на каждую ногу)\n- Поднимите одну ногу и вращайте стопой в одну и другую стороны.\n\n9. Завершающие растяжки\n- Проведите 2-3 минуты, делая растяжки для основных групп мышц, чтобы гарантировать максимальную подготовку к физической активности.\n\n\nПомимо вышеуказанных упражнений, вы можете добавить другие, которые соответствуют вашим индивидуальным потребностям. Главное – делать разминку медленно и аккуратно, чтобы избежать риска травм."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/ad/2e/dc/ad2edcf0dbb675dc7a7c5fc53944186d.jpg")!),
        TrainingRecommendation(title: "Тренировка пресса", exercises: [Exercise(name: "Тренировка пресса\n\n\nЦель: Укрепление мышц пресса, формирование рельефа.\n\n1. Планка\n   - Позиция: Лягте на живот, упритесь руками в пол под плечами.\n   - Выполнение: Поднимите тело на прямые руки и носки, создавая прямую линию от головы до пяток. Держитесь в этой позиции, напрягая пресс. Старайтесь не опускать таз и не поднимать задницу.\n   - Подходы: 3 подхода по 30 секунд.\n\n2. Поднятие ног лежа\n   - Позиция: Лягте на спину, руки вдоль тела или под ягодицы.\n   - Выполнение: Медленно поднимайте прямые ноги вверх до угла в 90 градусов, затем медленно опускайте их.\n   - Подходы: 3 подхода по 15 повторений.\n\n3. Велосипед\n   - Позиция: Лягте на спину, руки за головой, локти раскрыты.\n   - Выполнение: Поднимите ноги и имитируйте движение педалей на велосипеде, приближая противоположное колено к локтю при каждом \"вращении\".\n   - Подходы: 3 подхода по 30 секунд.\n\n4. Скручивания\n   - Позиция: Лягте на спину, ноги согнуты в коленях, руки за головой.\n   - Выполнение: Поднимайте верхнюю часть корпуса, напрягая мышцы пресса, и медленно возвращайтесь в исходное положение.\n   - Подходы: 3 подхода по 20 повторений.\n\n5. Русские скручивания\n   - Позиция: Сидите на полу, ноги подняты от пола, корпус немного отклонен назад.\n   - Выполнение: Держа руки перед собой, быстро поворачивайте корпус влево и вправо.\n   - Подходы: 3 подхода по 20 повторений (каждая сторона).\n\nПримечания:\n- Для достижения наилучших результатов выполняйте упражнения медленно и контролируемо.\n- Не забудьте провести разминку перед тренировкой и растяжку после.\n- Следите за дыханием: вдыхайте при опускании тела, выдыхайте при подъеме или напряжении."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/fc/5e/00/fc5e00674480397e93de5caa82f37e26.jpg")!),
        TrainingRecommendation(title: "Тренировка бицепса", exercises: [Exercise(name: "Тренировка бицепса\n\n1. Подберите подходящий вес. Для эффективного роста бицепса выберите такой вес, при котором выполнение 10-12 повторений будет вызывать усталость, но без потери техники.\n2. Стойка. Установите ноги на ширине плеч, держите спину прямо и кору тела стабильной.\n3. Сгибание рук с гантелями (Bicep Curls): Держа гантели в руках, медленно сгибайте руки в локтевых суставах, поднимая гантели к плечам. Затем медленно опустите гантели обратно.\n4. Молоток (Hammer Curls): Это похоже на обычное сгибание рук, но гантели держатся вертикально. Этот вид упражнения акцентирует внимание на внутреннем и внешнем головках бицепса, а также на брахиалисе.\n5. Сгибание рук на скамье (Incline Curls): Лягте на наклонную скамью с гантелями в руках. Сгибание рук на таком угле усиливает нагрузку на нижнюю часть бицепса.\n6. Концентрированные сгибания: Сидя на скамье, установите одну руку с гантелью между колен, другой рукой опирайтесь на колено. Сгибайте руку, концентрируясь на работе бицепса.\n7. Обратные сгибания рук (Reverse Curls): С помощью грифа штанги или EZ-грифа выполняйте сгибания, держа руки обратным хватом. Это упражнение также работает над брахиалисом и мышцами предплечья.\n8. Растяжка: После тренировки уделяйте время растяжке бицепса, чтобы улучшить гибкость и помочь в восстановлении.\n9. Отдых: Дайте бицепсу время для восстановления между тренировками. 48-72 часа между сессиями обычно достаточно.\n10. Следите за формой: Правильная техника важнее, чем вес, который вы поднимаете. Неправильная техника может привести к травмам и неэффективности упражнения.\n\nПомните, что консистентность и постоянство ключевые факторы успеха. Регулярные тренировки, правильное питание и достаточный отдых улучшат ваши результаты."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/8e/a1/11/8ea111f9b131f9e25c1141cc0b60087b.jpg")!),
        TrainingRecommendation(title: "Тренировка трицепса", exercises: [Exercise(name: "Тренировка трицепса\n\n1. Подберите оптимальный вес. Для эффективной тренировки трицепса выберите такой вес, при котором выполнение 10-12 повторений будет вызывать усталость, сохраняя при этом правильную технику.\n2. Стойка. Установите ноги на ширине плеч, держите спину прямо и кору тела активированной.\n3. Отжимания на брусьях: Это основное упражнение на трицепс, при котором работают все три головки мышцы.\n4. Французский жим: Лёжа на скамье, поднимите гантель или гриф штанги над грудью, сгибая и разгибая руки в локтях, акцентируя внимание на работе трицепса.\n5. Разгибание рук с гантелью за головой: Сидя или стоя, держите гантель двумя руками за головой и разгибайте руки в локтевом суставе.\n6. Разгибание рук на блоке: Стоя перед блоком, используйте веревку или прямой гриф, чтобы выполнять разгибание рук, концентрируясь на трицепсе.\n7. Отжимания с узким постановом рук: Выполняя отжимания на полу, установите руки ближе друг к другу, чтобы акцентировать нагрузку на трицепс.\n8. Растяжка: После тренировки проведите растяжку трицепса для лучшего восстановления и улучшения гибкости.\n9. Отдых: Позвольте трицепсу восстановиться между тренировками. Рекомендуется делать перерыв в 48-72 часа между сессиями.\n10. Следите за формой: Правильная техника важнее, чем вес, который вы используете. Неправильная техника может привести к травмам.\n\nПостоянство, правильное питание и достаточный отдых усилит эффективность вашей тренировки трицепса."
)], imageUrl: URL(string: "https://i.pinimg.com/originals/9c/87/18/9c8718e51e04c441764123f1574c52ca.gif")!),
        TrainingRecommendation(title: "Тренировка спины", exercises: [Exercise(name: "Тренировка спины\n\n1. Разминка: Проведите 5-10 минутную кардио-разминку для прогрева тела и подготовки спины к нагрузке.\n2. Тяга гантелей в наклоне: Стоя в наклоне, подтягивайте гантель к талии, работая лопаточными мышцами.\n3. Подтягивания: Отличное базовое упражнение для всей спины. Если сложно, начните с помощью тренажера или резиновых петель.\n4. Тяга штанги в наклоне: Упражнение на широчайшие мышцы спины. Соблюдайте технику, чтобы избежать травмы.\n5. Гиперэкстензия: Упражнение на поясничные мышцы. Можно выполнять с дополнительным весом или без него.\n6. Тяга вертикального блока: Сидя, тяните рукоять блока к груди или к затылку.\n7. Тяга горизонтального блока: Тяните рукоять к талии, чувствуя, как работают мышцы спины.\n8. Пуловер с гантелью: Лежа на скамье, держите гантель двумя руками и опускайте руки назад, затем возвращайтесь в исходное положение.\n9. Растяжка: После тренировки проведите растяжку спины и плечевого пояса для релаксации и профилактики травм.\n10. Отдых и регенерация: Мышцам спины также требуется отдых для восстановления. Постарайтесь дать им 48-72 часа перед следующей тренировкой.\n\nВнимание к технике выполнения упражнений и регулярные тренировки помогут вам развить крепкую и красивую спину."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/17/09/6e/17096e475dd3fc5b9df925fb84522931.jpg")!),
        TrainingRecommendation(title: "Тренировка груди", exercises: [Exercise(name: "Тренировка грудных мышц\n\n1. Разминка: Проведите 5-10 минутную кардио-разминку для повышения пульса и подготовки мышц к работе.\n2. Выбор веса: Определитесь с тем весом, при котором выполнение 8-12 повторений будет вызывать усталость, но при этом позволит сохранять правильную технику.\n3. Жим лежа: Это базовое упражнение для груди. Начните с барбелла или гантелей, поднимая и опуская вес над грудью.\n4. Разведение гантелей лежа: Лежа на скамье, держите гантель в каждой руке над грудью, а затем разводите руки в стороны и возвращайтесь в исходное положение.\n5. Отжимания: Стандартные отжимания хорошо работают на грудные мышцы. Постепенно увеличивайте количество повторений.\n6. Жим на наклонной скамье: Упражнение акцентирует внимание на верхней части груди.\n7. Пуловер с гантелью: Лежа на скамье, держите гантель двумя руками над грудью и опускайте руки назад, затем возвращайтесь в исходное положение.\n8. Разведение рук в тренажере бабочка: Сидя в тренажере, разводите и соединяйте руки, чувствуя напряжение в грудных мышцах.\n9. Растяжка: После тренировки проведите растяжку грудных мышц для улучшения гибкости и восстановления.\n10. Отдых и регенерация: Грудные мышцы, как и любые другие, нуждаются в отдыхе между тренировками. Дайте им 48-72 часа на восстановление перед следующей сессией.\n\nПомните о важности правильной техники и постоянстве для достижения наилучших результатов при тренировке груди."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/9c/99/49/9c9949325b4760afaabc5365660a823c.jpg")!),
        TrainingRecommendation(title: "Тренировка ног", exercises: [Exercise(name: "Тренировка ног\n\n1. Разминка: 5-10 минут кардио-разминки, чтобы прогреть мышцы и суставы.\n2. Приседания со штангой: Сосредоточьтесь на правильной технике, удерживая спину прямой и колени направленными вперёд.\n3. Жим ногами в тренажере: Выполняйте контролируемо, не отрывая спину от подушки тренажера.\n4. Румынская тяга со штангой: Отличное упражнение для задних бедер и ягодичных мышц. Не забудьте поддерживать прямую спину.\n5. Разгибание ног в тренажере: Упражнение на четырехглавую мышцу бедра.\n6. Сгибание ног в тренажере: Упражнение на двуглавую мышцу бедра.\n7. Выпады со штангой: Помогают развивать координацию и укреплять боковые мышцы бедра.\n8. Подъем на носки в тренажере: Целевая мышца - икроножные.\n9. Растяжка: После тренировки проведите растяжку всех мышечных групп ног для улучшения гибкости и предотвращения травм.\n10. Отдых: Мышцам ног требуется достаточно времени для восстановления. Обеспечьте им отдых минимум 48-72 часа до следующей тренировки.\n\nПридерживайтесь правильной техники, увеличивайте вес по мере прогресса и регулярно тренируйтесь для достижения наилучших результатов."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/a7/e3/4c/a7e34c6519bf4ab19ea7971049158fd5.jpg")!),
        TrainingRecommendation(title: "Тренировка для здоровья", exercises: [Exercise(name: "Тренировка для поддержания здоровья\n\n1. Разминка: 5-10 минут легкого кардио, такого как ходьба или медленный бег.\n2. Упражнения на гибкость: Включите в вашу тренировку упражнения на растяжку, чтобы улучшить гибкость и уменьшить риск травм.\n3. Кардио: 20-30 минут кардионагрузки, такой как бег, плавание или езда на велосипеде. Это поможет укрепить сердце и улучшить кровообращение.\n4. Силовые упражнения: Включите базовые упражнения для всех главных мышечных групп. Это поможет укрепить мышцы и улучшить общую физическую форму.\n5. Упражнения на равновесие: Попробуйте йогу или пилатес, чтобы улучшить равновесие и координацию.\n6. Релаксация и дыхательные упражнения: Посвятите несколько минут медитации или дыхательным упражнениям, чтобы снизить уровень стресса и улучшить концентрацию.\n7. Растяжка: Завершите тренировку растяжкой для улучшения гибкости и предотвращения мышечного дискомфорта.\n8. Гидратация: Не забывайте пить достаточное количество воды перед, во время и после тренировки.\n9. Правильное питание: Употребляйте сбалансированное питание, чтобы поддерживать уровень энергии и восстанавливать мышцы после тренировок.\n10. Отдых: Обеспечьте телу достаточный отдых между тренировками, спите не менее 7-8 часов в сутки для полного восстановления.\n\nСледуя этой инструкции, вы будете поддерживать свое здоровье и благосостояние на высоком уровне."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/ec/7a/ee/ec7aee9848f8f64a227830840c5b90ab.jpg")!),
        TrainingRecommendation(title: "Тренировка для похудения", exercises: [Exercise(name: "Тренировка для похудения\n\n1. Разминка: 5-10 минут активного кардио, такого как быстроходьба или медленный бег.\n2. Кардиоинтервалы: Чередуйте 1 минуту интенсивного кардио (бег, прыжки, быстрое велоспорт) с 1-2 минутами отдыха или легкой активности. Повторяйте 10-15 раз.\n3. Силовые упражнения: Выполняйте комплекс упражнений с отягощением для всех основных групп мышц, используя подходы 3х10-12 повторений.\n4. Кардио после силовой тренировки: 20-30 минут умеренного кардионагрузки, такой как езда на велосипеде или быстрая ходьба.\n5. Упражнения на выносливость: Включите упражнения с повышенной продолжительностью, такие как длительная прогулка или плавание.\n6. Упражнения на растяжку: После каждой тренировки уделяйте 5-10 минут растяжке для улучшения гибкости и уменьшения риска травм.\n7. Гидратация: Пейте воду перед, во время и после тренировки, чтобы поддерживать гидратацию и помогать телу сжигать калории.\n8. Здоровое питание: Сосредоточьтесь на сбалансированном питании, богатом белками и клетчаткой, и избегайте высококалорийных и жирных продуктов.\n9. Отдых: Позвольте своему телу восстанавливаться между тренировками, избегая чрезмерных нагрузок.\n10. Консультация с тренером: Рассмотрите возможность работы с тренером для составления индивидуальной программы тренировок.\n\nСледуя этой инструкции и придерживаясь здорового режима питания, вы сможете достичь своей цели по снижению веса."
)], imageUrl: URL(string: "https://i.pinimg.com/564x/99/cc/59/99cc59ca7722dc178558d1bb85bc9ebc.jpg")!)
    ]

    class HealthKitManager: ObservableObject {
        private var healthStore: HKHealthStore?

        init() {
            if HKHealthStore.isHealthDataAvailable() {
                healthStore = HKHealthStore()
            }
        }

        func requestAuthorization(completion: @escaping (Bool) -> Void) {
            guard let healthStore = self.healthStore else {
                completion(false)
                return
            }

            let allTypes = Set([
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!
                
            ])

            healthStore.requestAuthorization(toShare: [], read: allTypes) { (success, error) in
                completion(success)
            }
        }

        func fetchSteps(completion: @escaping (Double) -> Void) {
            fetchData(for: .stepCount, unit: HKUnit.count(), completion: completion)
        }

        func fetchActiveEnergy(completion: @escaping (Double) -> Void) {
            fetchData(for: .activeEnergyBurned, unit: HKUnit.kilocalorie(), completion: completion)
        }

        func fetchSleepAnalysis(completion: @escaping (Double) -> Void) {
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 0, sortDescriptors: nil) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    completion(0.0)
                    return
                }
                var totalSleep = 0.0
                for sleepSample in sleepSamples {
                    let sleepAmount = sleepSample.endDate.timeIntervalSince(sleepSample.startDate)
                    totalSleep += sleepAmount
                }
                completion(totalSleep / 3600) // Convert seconds to hours
            }

            healthStore?.execute(query)
        }
        func fetchAverageHeartRate(completion: @escaping (Double) -> Void) {
            guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                completion(0.0)
                return
            }
            
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                guard let result = result, let average = result.averageQuantity() else {
                    completion(0.0)
                    return
                }
                completion(average.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            }
            
            healthStore?.execute(query)
        }

        func fetchExerciseMinutes(completion: @escaping (Double) -> Void) {
            let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
            
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: exerciseTimeType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0.0)
                    return
                }
                completion(sum.doubleValue(for: HKUnit.minute()))
            }
            
            healthStore?.execute(query)
        }

        func fetchWeight(completion: @escaping (Double) -> Void) {
            let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
            
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], let lastSample = samples.first else {
                    completion(0.0)
                    return
                }
                completion(lastSample.quantity.doubleValue(for: HKUnit.gram().unitDivided(by: .gram())))
            }
            
            healthStore?.execute(query)
        }
        private func fetchData(for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
            let type = HKObjectType.quantityType(forIdentifier: typeIdentifier)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0.0)
                    return
                }
                completion(sum.doubleValue(for: unit))
            }

            healthStore?.execute(query)
        }
    }
    
    var body: some View {
            NavigationView {
                List {
                    // HealthKit data section
                    Section(header: Text("Мое здоровье")) {
                        VStack(spacing: 20) { // Добавлено вертикальное расстояние между HStack
                            HStack(spacing: 20) {
                                Spacer() // Расширитель
                                HealthDetailView(detail: HealthDetail(title: "Calories", value: activeEnergy, unit: "kCal", color: Color.green, sfSymbol: nil, maxValue: 200))
                                Spacer() // Расширитель
                                HealthDetailView(detail: HealthDetail(title: "Exercise", value: 12, unit: "min", color: Color.orange, sfSymbol: nil, maxValue: 30))
                                Spacer() // Расширитель
                                HealthDetailView(detail: HealthDetail(title: "Steps", value: steps, unit: "Steps", color: Color.blue, sfSymbol: nil, maxValue: 10000))
                                Spacer() // Расширитель
                            }

                            HStack(spacing: 20) {
                                Spacer() // Расширитель
                                HealthDetailView(detail: HealthDetail(title: "Sleep", value: sleepAnalysis, unit: "Hours", color: Color.purple, sfSymbol: "bed.double", maxValue: 1))
                                Spacer() // Расширитель
                                HealthDetailView(detail: HealthDetail(title: "Heart Rate", value: averageHeartRate, unit: "bpm", color: Color.red, sfSymbol: "heart.fill", maxValue: 1))
                                Spacer() // Расширитель
                            }
                        }
                        .padding(.vertical) // Вертикальные отступы
                        .frame(minHeight: 200) // Установка минимальной высоты для верхней части
                    }





                    // Training recommendations section
                    Section(header: Text("Тренировки")) {
                        ForEach(recommendations, id: \.title) { recommendation in
                            NavigationLink(destination: ExerciseDetailView(exercises: recommendation.exercises, imageUrl: recommendation.imageUrl,  eventsViewModel: eventsViewModel)) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(recommendation.title)
                                        .font(.headline)
                                    RemoteImage(url: recommendation.imageUrl)
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                        .scaledToFit()
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Тренировки")
                .onAppear {
                    healthKitManager.requestAuthorization { success in
                        if success {
                            healthKitManager.fetchSteps { stepsCount in
                                self.steps = stepsCount
                            }
                            healthKitManager.fetchActiveEnergy { energy in
                                self.activeEnergy = energy
                            }
                            healthKitManager.fetchSleepAnalysis { sleep in
                                self.sleepAnalysis = sleep
                            }
                            healthKitManager.fetchAverageHeartRate { averageRate in
                                            self.averageHeartRate = averageRate
                                        }
                            healthKitManager.fetchExerciseMinutes { minutes in
                                self.exerciseMinutes = minutes
                            }
//                            healthKitManager.fetchWeight { kg in
//                                self.weight = kg
//                            }

                        }
                    }
                }
            }
        }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingRecommendationsView()
    }
}



struct ExerciseDetailView: View {

    @ObservedObject var eventsViewModel: EventsViewModel  // предполагается, что EventsViewModel содержит текущего пользователя
    var exercises: [Exercise]
    var imageUrl: URL

    init(exercises: [Exercise], imageUrl: URL, eventsViewModel: EventsViewModel) {
            self.exercises = exercises
            self.imageUrl = imageUrl
            self.eventsViewModel = eventsViewModel
            // Нет необходимости устанавливать конфигурацию Realm здесь
            // Realm уже был настроен в RealmManager
        }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RemoteImage(url: imageUrl)
                    .scaledToFit()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                    .padding()

                ForEach(exercises, id: \.name) { exercise in
                    VStack {
                        Text(exercise.name)
                            .padding()
                        Button("Выполнил") {
                            completeExercise()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                }
            }
            .padding()
        }
    }

    private func completeExercise() {
            guard let currentUser = eventsViewModel.currentUser else {
                print("Текущий пользователь не найден.")
                return
            }
            do {
                let realm = try RealmManager.shared.getRealm()
                try realm.write {
                    currentUser.goPoints += 5
                    realm.add(currentUser, update: .modified)
                }
            } catch {
                print("Ошибка при добавлении GoPoints: \(error.localizedDescription)")
            }
        }
}



struct FoodItem: Identifiable {
    let id: UUID = UUID()
    let title: String
    let thumbnail: String // Это теперь SF Symbol name
    let description: String
    let imageURL: URL
}

struct NutritionView: View {
    let items: [FoodItem] = [
        FoodItem(title: "Вегетарианство", thumbnail: "leaf.fill", description: "Инструкция по Вегетарианству\n\n1. Определите свой вид вегетарианства:\n   - Лакто-ово-вегетарианцы: исключают мясо, рыбу и птицу, но потребляют молочные продукты и яйца.\n   - Лакто-вегетарианцы: исключают мясо, рыбу, птицу и яйца, но потребляют молочные продукты.\n   - Ово-вегетарианцы: исключают мясо, рыбу, птицу и молочные продукты, но потребляют яйца.\n   - Веганы: исключают все продукты животного происхождения.\n\n2. **Информируйтесь**: Изучите пользу и возможные риски вегетарианского питания. Книги, сайты и диетологи могут помочь вам с этим.\n\n3. Планирование меню: Гарантируйте, что вы получаете все необходимые витамины и минералы. Особое внимание уделите белку, железу, кальцию, цинку и витамину B12.\n\n4. Разнообразие: Стремитесь к разнообразию в вашем рационе. Включите в него разные зерновые, бобовые, орехи, семена, овощи и фрукты.\n\n5. Читайте состав продуктов: Некоторые продукты, которые кажутся вегетарианскими, могут содержать животные ингредиенты.\n\n6. Готовьте дома: Это позволит вам контролировать ингредиенты и исследовать разнообразные вегетарианские рецепты.\n\n7. Будьте готовы к вопросам: Многие люди будут интересоваться вашим выбором в пользу вегетарианства, поэтому будьте готовы обсудить и объяснить свои причины.\n\n8. Листайте меню: Когда вы находитесь в ресторане, ищите вегетарианские или веганские опции или просите адаптировать блюда под ваш рацион.\n\n9. Социализация: Присоединяйтесь к вегетарианским группам или сообществам в вашем регионе или онлайн, чтобы обмениваться опытом и рецептами.\n\n10. Уважайте выбор других: Все люди разные, и у каждого свои взгляды на питание. Уважайте выбор других, даже если он отличается от вашего."
, imageURL: URL(string: "https://i.pinimg.com/564x/09/9b/58/099b58b35a10aa072f3243257223c1ef.jpg")!),
        FoodItem(title: "Набор мышечной массы", thumbnail: "figure.run", description: "Инструкция:\n - 1. Увеличьте калорийный прием. Потребляйте на 250-500 ккал больше, чем вы тратите в течение дня, чтобы обеспечить позитивное калорийное равновесие.\n - 2. Выберите белковые продукты высокого качества. Цель - потребление 1,6–2,2 г белка на кг телесного веса. Оптимальные источники: мясо, рыба, яйца, молочные продукты, бобовые и орехи.\n - 3. Не забывайте о углеводах. Углеводы - основной источник энергии. Потребляйте сложные углеводы: цельнозерновые, каши, овощи, фрукты.\n - 4. Включите здоровые жиры. Орехи, авокадо, оливковое и льняное масло предоставят вашему телу необходимые жиры и калории.\n - 5. Пейте достаточно воды. Гидратация помогает в процессе восстановления и роста мышц.\n - 6. Распределяйте пищу равномерно. Стремитесь к 5-6 приемам пищи в день, чтобы обеспечить стабильное поступление питательных веществ.\n - 7. Потребляйте углеводы и белок после тренировки. Это поможет в восстановлении гликогена и стимуляции роста мышц.\n - 8. Ограничьте потребление алкоголя и добавленного сахара. Они могут препятствовать набору чистой мышечной массы.\n - 9. Рассмотрите возможность применения добавок. Протеиновые порошки, креатин или аминокислоты могут быть полезными для стимуляции роста мышц.\n - 10. Слушайте свое тело. Если вы чувствуете себя голодным, увеличьте калорийное потребление. Если вы набираете лишний вес слишком быстро, уменьшите калории.\n\nВажно помнить, что набор мышечной массы требует сочетания правильного питания, силовых тренировок и отдыха. Всегда рекомендуется проконсультироваться с фитнес-тренером или диетологом, чтобы создать индивидуализированный план."
, imageURL: URL(string: "https://i.pinimg.com/564x/57/e7/9e/57e79e749858aad898dd3a0ee64052d5.jpg")!),
        FoodItem(title: "Для похудения", thumbnail: "figure.run", description: "Питание для похудения\n\n1. Пить воду: Употребляйте минимум 2-2,5 литра воды в день. Начните день с стакана воды.\n2. Завтрак: Не пропускайте завтрак. Оптимальный выбор - белково-углеводная комбинация, например, омлет с овощами и гречка.\n3. Частые приемы пищи: Ешьте небольшие порции 5-6 раз в день.\n4. Ограничьте углеводы: Сократите потребление быстрых углеводов (сладости, белый хлеб).\n5. Больше белка: Включите в рацион магерый белок - курятина, индейка, рыба, творог.\n6. Ограничьте жиры: Избегайте жирного мяса, майонеза, жареной пищи.\n7. Овощи и фрукты: Включайте их в каждый прием пищи, но остерегайтесь слишком сладких фруктов.\n8. Замените сладости: Если хочется чего-то сладкого, выбирайте темный шоколад или сухофрукты в малых количествах.\n9. Уменьшите потребление соли: Это поможет избежать задержки воды в организме.\n10. Алкоголь и газированные напитки: Сократите их употребление или исключите вовсе.\n11. Планируйте свои приемы пищи: Подготовьте еду заранее, чтобы избежать привлечения к быстрой еде или закускам.\n12. Читайте состав продуктов: Избегайте продуктов с высоким содержанием сахара, соли или трансжиров.\n\nСледуя этим рекомендациям и соблюдая режим физической активности, вы сможете снижать вес здоровым и безопасным способом."
, imageURL: URL(string: "https://i.pinimg.com/564x/94/29/60/942960f77569ae64fce11efd850b2218.jpg")!),
        FoodItem(title: "Для поддержания формы", thumbnail: "figure.run", description: "Питание для поддержания формы\n\n1. Регулярные приемы пищи: Стремитесь к трем основным приемам пищи и двум закускам в течение дня.\n2. Баланс макроэлементов: Поддерживайте баланс белков, углеводов и жиров в своем рационе.\n3. Употребляйте достаточно воды: Цель - 2 литра воды в день, или больше при активных тренировках.\n4. Ограничивайте быстрые углеводы: Предпочитайте сложные углеводы, такие как крупы, овощи и цельнозерновой хлеб.\n5. Белки: Включайте в рацион источники качественного белка - мясо, рыбу, яйца, бобовые.\n6. Здоровые жиры: Орехи, авокадо, оливковое масло и жирная рыба - источники полезных жиров.\n7. Ограничьте соль и сахар: Это поможет избежать лишнего водосбережения и колебаний уровня сахара в крови.\n8. Алкоголь: Ограничьте его употребление до минимума или исключите.\n9. Не пропускайте завтрак: Он помогает запустить обмен веществ и предоставляет энергию на весь день.\n10. Закуски: Выбирайте здоровые варианты, такие как орехи, семена или овощи с нежирным творогом.\n11. Разнообразие: Стремитесь к разнообразию в пище, чтобы обеспечить получение всех необходимых микроэлементов.\n12. Слушайте свой организм: Ешьте, когда чувствуете голод, и останавливайтесь, когда насыщены.\n\nПоддержание формы - это баланс между правильным питанием и регулярными физическими упражнениями. Следуя этим рекомендациям, вы сможете сохранять свою форму и оставаться в тонусе."
, imageURL: URL(string: "https://i.pinimg.com/564x/84/59/9d/84599d55816bea5e2117a4e93259c840.jpg")!),
        // Добавьте другие элементы здесь
    ]
    
    @State private var selectedFood: FoodItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    // Секция "Стили питания"
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Стили питания")
                            .font(.headline)
                            .padding(.top)

                        ForEach(items) { item in
                            NavigationLink(destination: NutritionDetailView(foodItem: item)) {
                                HStack {
                                    Image(systemName: item.thumbnail)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.blue)
                                    Text(item.title)
                                        .font(.body)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading) // Установка максимальной ширины
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding([.horizontal, .top, .bottom])
                }
            }
            .navigationBarTitle("Питание", displayMode: .inline)
        }
    }


}

struct NutritionDetailView: View {
    var foodItem: FoodItem

    var body: some View {
            ScrollView { // Добавление ScrollView для уверенности, что контент будет прокручиваться на устройствах с маленьким экраном
                VStack(spacing: 20) {
                    RemoteImage(url: foodItem.imageURL)
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width)
                        .padding(.top) // Отступ сверху для картинки

                    Text(foodItem.description)
                        .padding()
                }
                .padding(.horizontal) // Горизонтальные отступы для всего контента в VStack
            }
            .navigationBarTitle(foodItem.title, displayMode: .inline)
        }
}








struct NewsFeedView: View {
    var newsItems: [NewsItem] = [
        NewsItem(title: "Бесплатный абонемент", description: "🎉 Специальное предложение в сотрудничестве с фитнес-клубом Гора! 🎉 \n \n Друзья, мы рады объявить об уникальной акции для всех активных пользователей нашего приложения! В партнерстве с популярным фитнес-клубом Гора мы подготовили для вас потрясающий подарок. \n \n 🎁 Получите абонемент на полгода в фитнес-клуб Гора совершенно бесплатно! 🎁 \n \n Как это работает? Все просто: \n \n 1. Участвуйте в событиях через наше приложение. \n 2. После 50 участий в различных событиях вы автоматически становитесь участником акции. \n 3. Получите свой абонемент и начните заниматься спортом в одном из лучших фитнес-клубов города! \n \n Не упустите свой шанс стать частью спортивного сообщества и заботиться о своем здоровье вместе с нами и фитнес-клубом Гора!", imageUrl: URL(string: "https://thumb.tildacdn.com/tild6566-6538-4239-a362-343666313065/-/resize/358x/-/format/webp/3.png")!)
    ]
    
    var body: some View {
        NavigationView {
            List(newsItems) { item in
                VStack(alignment: .leading) {
                    Text(item.title).font(.headline)
                    RemoteImage(url: item.imageUrl)
                        .frame(height: 150)
                        .cornerRadius(8)
                    Text(item.description).font(.subheadline)
                }
            }
            .navigationTitle("Новости")
        }
    }
}
struct Event: Identifiable {
    var id = UUID()
    let address: String
    let sports: String
    let cost: String
    let date: Date
    let duration: String
    var participantsCount: Int
}
class EventRealm: Object {
    @objc dynamic var id: String = UUID().uuidString
    @objc dynamic var address: String = ""
    @objc dynamic var sports: String = ""
    @objc dynamic var cost: String = ""
    @objc dynamic var date: Date = Date()
    @objc dynamic var duration: String = ""
    @objc dynamic var participantsCount: Int = 0
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
class EventsViewModel: ObservableObject {
    init() {
            self.realm = try! RealmManager.shared.getRealm()
            loadEventsFromRealm()
            loadUserProfile()
        }
    private var realm: Realm
    @Published var participatedEventsCount: Int = 0
    @Published var currentUser: User?
    
//    private var currentUser: User? // это новая строка
    func setCurrentUser(_ user: User) {
        self.currentUser = user
    }

    @Published var events: [Event] = []
    @Published var joinedEvents: Set<String> = [] 
    @Published var createdEventsByUser: Set<String> = []

    

    func joinEvent(_ event: Event) {
        if !joinedEvents.contains(event.id.uuidString) {
            if let eventRealm = realm.object(ofType: EventRealm.self, forPrimaryKey: event.id.uuidString) {
                do {
                    try realm.write {
                        eventRealm.participantsCount += 1
                        
                        // Обновляем eventsCount и goPoints для текущего пользователя
                        if let user = currentUser {
                            user.eventsCount += 1
                            user.goPoints += 10 // Допустим, мы добавляем 10 goPoints за присоединение к событию
                            
                            // Сохраняем измененный объект пользователя
                            realm.add(user, update: .modified)
                        } else {
                            // Обработка ситуации, когда currentUser не установлен
                            print("Текущий пользователь не найден.")
                        }
                    }
                    joinedEvents.insert(event.id.uuidString)
                    loadEventsFromRealm()
                    
                    // Уведомляем об изменении, чтобы обновить UserProfileView
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                    }
                } catch {
                    // Обработка ошибки записи в Realm
                    print("Ошибка при попытке присоединиться к событию: \(error.localizedDescription)")
                }
            } else {
                // Обработка случая, когда событие не найдено в Realm
                print("Событие не найдено в Realm.")
            }
        }
    }





    func loadUserProfile() {
            do {
                let realm = try Realm()
                if let userID = UserDefaults.standard.value(forKey: "currentUserID") as? String,
                   let loadedUser = realm.object(ofType: User.self, forPrimaryKey: userID) {
                    self.currentUser = loadedUser
                    DispatchQueue.main.async {
                        self.objectWillChange.send() // Уведомляем View об изменении
                    }
                }
            } catch {
                print("Ошибка при загрузке профиля: \(error)")
            }
        }



    func createEvent(address: String, sports: String, cost: String, date: Date, duration: String) {
        let newEvent = EventRealm()
        newEvent.address = address
        newEvent.sports = sports
        newEvent.cost = cost
        newEvent.date = date
        newEvent.duration = duration

        try! realm.write {
            realm.add(newEvent)
        }
        createdEventsByUser.insert(newEvent.id)
        loadEventsFromRealm()
    }


    private func loadEventsFromRealm() {
        let eventsRealm = realm.objects(EventRealm.self)
        events = eventsRealm.map { Event(id: UUID(uuidString: $0.id)!, address: $0.address, sports: $0.sports, cost: $0.cost, date: $0.date, duration: $0.duration, participantsCount: $0.participantsCount) }
    }


    func deleteEvent(event: Event) {
            if let eventRealm = realm.object(ofType: EventRealm.self, forPrimaryKey: event.id.uuidString) {
                do {
                    try realm.write {
                        realm.delete(eventRealm)
                    }
                    createdEventsByUser.remove(event.id.uuidString)
                    if let index = events.firstIndex(where: { $0.id == event.id }) {
                        events.remove(at: index)
                    }
                } catch {
                    print("Ошибка при удалении события: \(error.localizedDescription)")
                }
            } else {
                print("Событие не найдено в Realm")
            }
        }



}





struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @State private var isCreatingEvent: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.events) { event in
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "sportscourt")
                            Text(event.sports)
                        }
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(event.address)
                        }
                        HStack {
                            Image(systemName: "calendar")
                            Text(event.date, style: .date)
                        }
                        HStack {
                            Image(systemName: "clock")
                            Text(event.duration)
                        }
                        HStack {
                            Image(systemName: "person.fill")
                            Text("\(event.participantsCount) участников")
                        }
                        Button(action: {
                            viewModel.joinEvent(event)
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Присоединиться")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.joinedEvents.contains(event.id.uuidString))
                        .opacity(viewModel.joinedEvents.contains(event.id.uuidString) ? 0.5 : 1)
                    }
                    .contextMenu {
                            if viewModel.createdEventsByUser.contains(event.id.uuidString) {
                                Button(action: {
                                    viewModel.deleteEvent(event: event)
                                }) {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }


                }
                .onDelete(perform: deleteEvent)
            }
            .navigationTitle("События")
            .navigationBarItems(trailing: Button(action: {
                isCreatingEvent.toggle()
            }) {
                Text("Создать событие")
            })
            .sheet(isPresented: $isCreatingEvent) {
                CreateEventView(viewModel: viewModel)
            }
        }
    }
    
    func deleteEvent(at offsets: IndexSet) {
            offsets.forEach { index in
                let event = viewModel.events[index]
                viewModel.deleteEvent(event: event)
            }
        }

}

struct CreateEventView: View {
    @ObservedObject var viewModel: EventsViewModel
    
    @State private var address: String = ""
    @State private var sports: String = ""
    @State private var cost: String = ""
    @State private var date: Date = Date()
    @State private var duration: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            TextField("Адрес", text: $address)
            TextField("Виды спорта", text: $sports)
            TextField("Стоимость", text: $cost)
            DatePicker("Дата", selection: $date)
            TextField("Продолжительность", text: $duration)
            Button("Создать событие") {
                viewModel.createEvent(address: address, sports: sports, cost: cost, date: date, duration: duration)
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
        .navigationTitle("Новое событие")
    }
}
struct DailyTask {
    var title: String
    var currentValue: Double
    var goalValue: Double
    var unit: String
    var sfSymbolName: String
}

struct DailyTasksView: View {
    @StateObject private var healthKitManager = HealthKitManager()
//    @ObservedObject var healthKitManager: HealthKitManager
    class HealthKitManager: ObservableObject {
        private var healthStore: HKHealthStore?

        init() {
            if HKHealthStore.isHealthDataAvailable() {
                healthStore = HKHealthStore()
            }
        }

        func requestAuthorization(completion: @escaping (Bool) -> Void) {
            guard let healthStore = self.healthStore else {
                completion(false)
                return
            }

            let allTypes = Set([
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)! // Добавьте это

            ])

            healthStore.requestAuthorization(toShare: [], read: allTypes) { (success, error) in
                completion(success)
            }
        }

        func fetchSteps(completion: @escaping (Double) -> Void) {
            fetchData(for: .stepCount, unit: HKUnit.count(), completion: completion)
        }

        func fetchActiveEnergy(completion: @escaping (Double) -> Void) {
            fetchData(for: .activeEnergyBurned, unit: HKUnit.kilocalorie(), completion: completion)
        }
        func fetchDistance(completion: @escaping (Double) -> Void) {
            fetchData(for: .distanceWalkingRunning, unit: HKUnit.meter(), completion: completion)
        }
        func fetchSleepAnalysis(completion: @escaping (Double) -> Void) {
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 0, sortDescriptors: nil) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    completion(0.0)
                    return
                }
                var totalSleep = 0.0
                for sleepSample in sleepSamples {
                    let sleepAmount = sleepSample.endDate.timeIntervalSince(sleepSample.startDate)
                    totalSleep += sleepAmount
                }
                completion(totalSleep / 3600) // Convert seconds to hours
            }

            healthStore?.execute(query)
        }

        private func fetchData(for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
            let type = HKObjectType.quantityType(forIdentifier: typeIdentifier)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0.0)
                    return
                }
                completion(sum.doubleValue(for: unit))
            }

            healthStore?.execute(query)
        }
    }
    @State var dailyTasks: [DailyTask] = [
        DailyTask(title: "Шаги", currentValue: 0, goalValue: 10000, unit: "шагов", sfSymbolName: "figure.walk"),
        DailyTask(title: "Активные калории", currentValue: 0, goalValue: 200, unit: "кал", sfSymbolName: "flame"),
        DailyTask(title: "Пройденная дистанция", currentValue: 3, goalValue: 5, unit: "км", sfSymbolName: "map")
    ]

    var body: some View {
        VStack(spacing: 15) {
            ForEach(dailyTasks.indices, id: \.self) { index in
                HStack {
                    Image(systemName: dailyTasks[index].sfSymbolName)
                        .font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(dailyTasks[index].title)
                            .font(.headline)
                        Text("\(dailyTasks[index].currentValue, specifier: "%.1f") \(dailyTasks[index].unit) из \(dailyTasks[index].goalValue, specifier: "%.1f") \(dailyTasks[index].unit)")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    ProgressBar(value: dailyTasks[index].currentValue, maxValue: dailyTasks[index].goalValue)
                        .frame(height: 20)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
            }
        }
        .onAppear(perform: loadData)
        .padding()
    }

    func loadData() {
        healthKitManager.fetchSteps { steps in
            dailyTasks[0].currentValue = steps
        }
        healthKitManager.fetchActiveEnergy { energy in
            dailyTasks[1].currentValue = energy
        }
        healthKitManager.fetchDistance { distance in
            dailyTasks[2].currentValue = distance
        }
        // Вы можете добавить функционал для дистанции здесь, используя аналогичный метод
    }
}

struct ProgressBar: View {
    var value: Double
    var maxValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = CGFloat(value / maxValue)
            Rectangle()
                .fill(value >= maxValue ? Color.green : Color.blue) // Изменение тут
                .frame(width: width * progress)
                .animation(.linear)
        }
        .frame(height: 10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(5)
    }
}
    
struct ProCabinetView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Подписка Go Fit")
                    .font(.largeTitle)
                    .padding(.top)

                Group {
                    HStack {
                        Image(systemName: "plus.circle.fill")  // Иконка
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Повышенные Go баллы")
                                .font(.headline)
                            Text("С Pro подпиской вы получаете в 2 раза больше Go баллов за каждое выполненное действие.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Divider()

                Group {
                    HStack {
                        Image(systemName: "calendar.circle.fill")  // Иконка
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Ежедневное начисление баллов")
                                .font(.headline)
                            Text("Каждый день вам начисляются дополнительные баллы, благодаря вашей Pro подписке.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Divider()

                Group {
                    HStack {
                        Image(systemName: "star.circle.fill")  // Иконка
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading) {
                            Text("Эксклюзивные тренировки")
                                .font(.headline)
                            Text("Получите доступ к тренировкам, которые доступны только для Pro пользователей.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Divider()

                Group {
                    HStack {
                        Image(systemName: "heart.circle.fill")  // Иконка
                            .foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Расширенная статистика 'Мое здоровье'")
                                .font(.headline)
                            Text("С Pro подпиской у вас будет доступ к более детальной статистике о вашем здоровье.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer().frame(height: 30)

                HStack {
                    Spacer()
                    Button(action: {
                        // Код для обработки внутренней покупки
                    }) {
                        Text("Оформить за 199 руб/месяц")
                            .font(.headline)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    Spacer()
                }

            }
            .padding()
        }
    }
}

struct ProCabinetView_Previews: PreviewProvider {
    static var previews: some View {
        ProCabinetView()
    }
}
// Структура для предмета в магазине
struct ShopItem: Identifiable {
    let id = UUID()
    let name: String
    let imageUrl: URL
    let cost: Int
}

// Обновленное представление для страницы магазина с использованием ObservedObject для GoPoints
struct ShopView: View {
    @ObservedObject var eventsViewModel: EventsViewModel

    // Пример списка предметов в магазине
    let items: [ShopItem] = [
        ShopItem(name: "Кроссовки Nike Downshifter 12", imageUrl: URL(string: "https://a.lmcdn.ru/img600x866/M/P/MP002XM0B4SQ_21088808_1_v1.jpg")!, cost: 10000),
        ShopItem(name: "Спортивная майка Nike", imageUrl: URL(string:"https://a.lmcdn.ru/pi/img600x866/R/T/RTLAAR357501_15207200_1_v1.jpg")!, cost: 4000),
        ShopItem(name: "Спортивные шорты Nike", imageUrl: URL(string:"https://cdn.sportmaster.ru/upload/resize_cache/iblock/4d0/768_1024_1/51055900299.jpg")!, cost: 5000),
        ShopItem(name: "Гантели 1кг", imageUrl: URL(string:"https://cdn.sportmaster.ru/upload/resize_cache/iblock/011/1008_800_1/58007200299.jpg")!, cost: 1000),
        ShopItem(name: "Гантели 2кг", imageUrl: URL(string:"https://cdn.sportmaster.ru/upload/resize_cache/iblock/c08/1008_800_1/58007270299.jpg")!, cost: 1500),
        ShopItem(name: "Гантели 3кг", imageUrl: URL(string:"https://cdn.sportmaster.ru/upload/resize_cache/iblock/dfa/1008_800_1/58007280299.jpg")!, cost: 2000),
        ShopItem(name: "Гантели 5кг", imageUrl: URL(string:"https://cdn.sportmaster.ru/upload/resize_cache/iblock/04f/1008_800_1/58007370299.jpg")!, cost: 2500)]
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack {
                        Text("Ваши GoPoints: \(eventsViewModel.currentUser?.goPoints ?? 0)")
                            .font(.title)
                            .padding()
                        
                        ForEach(items) { item in
                            HStack {
                                // Use AsyncImage to load an image from a URL
                                AsyncImage(url: item.imageUrl) { image in
                                    image.resizable() // Make the loaded image resizable
                                } placeholder: {
                                    ProgressView() // Show a progress view while the image is loading
                                }
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                
                                Text(item.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Action for purchasing the item
                                    purchaseItem(item: item)
                                }) {
                                    Text("\(item.cost) GoPoints")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(eventsViewModel.currentUser?.goPoints ?? 0 >= item.cost ? Color.blue : Color.gray)
                                        .cornerRadius(10)
                                }
                                .disabled(eventsViewModel.currentUser?.goPoints ?? 0 < item.cost)
                            }
                            .padding()
                        }
                    }
                }
                .navigationBarTitle("Магазин", displayMode: .inline)
            }
        }
    
    private func purchaseItem(item: ShopItem) {
        if let userGoPoints = eventsViewModel.currentUser?.goPoints, userGoPoints >= item.cost {
            // Здесь обновляем GoPoints пользователя после покупки
            eventsViewModel.currentUser?.goPoints -= item.cost
            // Здесь может быть код для обработки покупки, например, сохранение в базу данных или обновление ViewModel
        } else {
            // Можно показать сообщение, что недостаточно GoPoints
        }
    }
}

struct UserProfileView: View {
    
    @State private var eventsCount: Int = 0
    @State private var isProUser: Bool = true
    @State private var stepsToday: Int = 0
    @Binding var username: String
    @ObservedObject var eventsViewModel = EventsViewModel()
    @Binding var isLoggedIn: Bool
    let name: String = ""
    let eventsParticipated: Int = 0
    @State private var achievements: Int = 0
    let trainingsViewed: Int = 0
    
    
    func getStepsFromHealthKit() {
        let healthStore = HKHealthStore()
        let stepsQuantityType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        healthStore.requestAuthorization(toShare: [], read: [stepsType]) { success, error in            if success {
                // Теперь вы можете получить данные о шагах
                getStepsFromHealthKit()
            } else if let error = error {
                print("Ошибка запроса разрешения HealthKit: \(error.localizedDescription)")
            }
        }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepsQuantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    print("Ошибка получения данных о шагах: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                    return
                }

                stepsToday = Int(sum.doubleValue(for: HKUnit.count()))
            }
        }

        healthStore.execute(query)
    }

    @State private var profileImage: UIImage?
    @State private var isImagePickerShowing = false
    
    struct ImagePicker: UIViewControllerRepresentable {
        @Binding var image: UIImage?
        @Binding var isShown: Bool
        var onImagePicked: (UIImage) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self, onImagePicked: onImagePicked)
        }

        class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let parent: ImagePicker
            var onImagePicked: (UIImage) -> Void

            init(_ parent: ImagePicker, onImagePicked: @escaping (UIImage) -> Void) {
                self.parent = parent
                self.onImagePicked = onImagePicked
            }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                if let image = info[.originalImage] as? UIImage {
                    parent.image = image
                    onImagePicked(image)
                }
                parent.isShown = false
            }
        }
    }

    var body: some View {
            NavigationView {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Доброе утро,")
                                    .font(.headline)
                                HStack {
                                    Text("\(username)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    if isProUser {
                                        Text("Pro")
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue)
                                            .cornerRadius(15)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.top, 25)
                            Spacer()

                            Button(action: {
                                self.isImagePickerShowing = true
                            }) {
                                if let profilePictureData = eventsViewModel.currentUser?.profilePicture, let image = UIImage(data: profilePictureData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                        .padding(.leading, -50)
                                        .padding(.top, 20)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                        .padding(.leading, -50)
                                        .padding(.top, 20)
                                }
                            }
                            .sheet(isPresented: $isImagePickerShowing) {
                                ImagePicker(image: $profileImage, isShown: $isImagePickerShowing, onImagePicked: { img in
                                    updateProfileImage(img)
                                })
                            }
                        }
                        
                        HStack(spacing: 40) {
                            CircleStatView(imageName: "calendar.badge.plus", value: "\(eventsViewModel.currentUser?.eventsCount ?? 0)", label: "Событий")
                            CircleStatView(imageName: "star.fill", value: "\(eventsViewModel.currentUser?.goPoints ?? 0)", label: "Go Баллы")
                            CircleStatView(imageName: "figure.walk", value: "\(stepsToday)", label: "Шагов")
                        }
                        .padding(.top, 20)
                        
                        NavigationLinkButton(title: "Ежедневные задачи", destination: DailyTasksView())
                        NavigationLinkButton(title: "Новости", destination: NewsFeedView())
                        NavigationLinkButton(title: "Магазин", destination: ShopView(eventsViewModel: eventsViewModel))
                        NavigationLinkButton(title: "Go Fit Pro", destination: ProCabinetView())
                        
                        Button(action: logout) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Выйти")
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    loadUserProfile()
                    getStepsFromHealthKit()
                }
            }
        }
    func logout() {
        UserDefaults.standard.removeObject(forKey: "isUserLoggedIn")
        UserDefaults.standard.removeObject(forKey: "currentUserID")
        isLoggedIn = false
        eventsViewModel.loadUserProfile()  // Загрузите профиль при выходе

    }


    func loadUserProfile() {
            do {
                let realm = try Realm()
                if let userID = UserDefaults.standard.value(forKey: "currentUserID") as? String,
                   let currentUser = realm.object(ofType: User.self, forPrimaryKey: userID) {
                    username = currentUser.username
                    eventsCount = currentUser.eventsCount
                    
                    
                    // Устанавливаем текущего пользователя для eventsViewModel
                    eventsViewModel.setCurrentUser(currentUser)
                }
            } catch {
                print("Ошибка при загрузке профиля: \(error)")
            }
        }
    private func updateProfileImage(_ image: UIImage) {
            do {
                let realm = try Realm()
                if let userID = UserDefaults.standard.value(forKey: "currentUserID") as? String, let currentUser = realm.object(ofType: User.self, forPrimaryKey: userID) {
                    try realm.write {
                        currentUser.profilePicture = image.jpegData(compressionQuality: 0.8)
                    }
                    // Обновляем локальное состояние
                    self.profileImage = image
                    // Обновляем данные во ViewModel
                    eventsViewModel.setCurrentUser(currentUser)
                }
            } catch {
                print("Ошибка при обновлении изображения профиля: \(error)")
            }
        }
    func updateProfile() {
            username = eventsViewModel.currentUser?.username ?? ""
            eventsCount = eventsViewModel.currentUser?.eventsCount ?? 0
        }



}
struct CircleStatView: View {
    let imageName: String
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(Circle())
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
        }
    }
}
struct NavigationLinkButton<Destination: View>: View {
    let title: String
    let destination: Destination

    init(title: String, destination: Destination) {
        self.title = title
        self.destination = destination
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ButtonView: View {
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct UserProfileView_Previews: PreviewProvider {
    @State static var isLoggedIn = true
    @State static var previewUsername = "Пользователь" //

    static var previews: some View {
        UserProfileView(username: $previewUsername, isLoggedIn: $isLoggedIn)
    }
}











struct ContentView: View {
    @State private var showSplash = true
    @State private var isLoggedIn: Bool = true
    @State private var currentUsername: String = ""

    var body: some View {
        TabView {
            SportPlacesView()
                .tabItem {
                    Label("Площадки", systemImage: "sportscourt")
                }
            
            TrainingRecommendationsView()
                .tabItem {
                    Label("Тренировки", systemImage: "heart.fill")
                }
            NutritionView()
                .tabItem {
                    Label("Питание", systemImage: "fork.knife")
                }
            EventsView()
                .tabItem {
                    Label("События", systemImage: "calendar")
                }
            
            UserProfileView(username: $currentUsername, isLoggedIn: $isLoggedIn)
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Профиль")
                }
        }
        .onAppear {
                NotificationManager.shared.requestAuthorization()
                LocationManager.shared.requestLocationPermission()


            }
    }
    
}

