//
//  UserInteractionWidgetTest.swift
//  UserInteractionWidgetTest
//
//  Created by Harsha R Mundaragi  on 18/10/23.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), images: [UIImage(imageLiteralResourceName: "testImage01"),UIImage(imageLiteralResourceName: "testImage02"),UIImage(imageLiteralResourceName: "testImage03")], category: "all")
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, images: [UIImage(imageLiteralResourceName: "testImage01"),UIImage(imageLiteralResourceName: "testImage02"),UIImage(imageLiteralResourceName: "testImage03")], category: "all")
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            guard let image = try? await DataFetcher.fetchMovieDetails(category: configuration.customCategory?.identifier ?? "all") else {
                return
            }
            let currentDate = Date()
            let startOfDay = Calendar.current.startOfDay(for: currentDate)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            let entry = SimpleEntry(date: startOfDay, configuration: configuration, images: Array(image), category: configuration.customCategory?.identifier ?? "all")
            let timeline = Timeline(entries: [entry],policy: .after(endOfDay))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let images: [UIImage]?
    var category = "all"
    
    
    var appUrl: URL {
        guard let url = URL(string: "userinteractivewidget//:category/\(category)") else{
            fatalError("unable to create app url")
        }
        
        return url
    }
}

struct UserInteractionWidgetTestEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Link(destination: entry.appUrl, label: {
            ZStack{
                ContainerRelativeShape()
                    .fill(.brown.gradient.opacity(0.6))
                VStack{
                    Text("Trending Category: \(entry.configuration.customCategory?.displayString ?? "All")")
                        .font(.body)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundColor(.brown)
                        .padding(.top, 5)
    //                    .widgetURL(entry.appUrl)
                    HStack{
                        ForEach(entry.images!, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.5), radius: 8, x: 5, y: 5)
                                .frame(width: 80, height:  90)
                                .padding(5)
                        }
                    }
                    
                    Spacer()
                }
                
            }
        })
    }
}

struct UserInteractionWidgetTest: Widget {
    let kind: String = "UserInteractionWidgetTest"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            UserInteractionWidgetTestEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemMedium])
    }
}

struct UserInteractionWidgetTest_Previews: PreviewProvider {
    static var previews: some View {
        UserInteractionWidgetTestEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), images: [UIImage(imageLiteralResourceName: "testImage01"),UIImage(imageLiteralResourceName: "testImage02"),UIImage(imageLiteralResourceName: "testImage03")], category: "all"))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}


struct ResultData: Decodable {
    let results: [AllDetails]
}

struct AllDetails: Decodable {
    let backdrop_path: String
    let id: Int
    let title: String?
    let original_title: String?
    let name: String?
    let poster_path: String
    let media_type: String
    
    
    var imageUrl: URL? {
        return URL(string: "https://image.tmdb.org/t/p/w500\(poster_path)")
    }
}


struct DataFetcher {
    
    enum DataFetcherError: Error {
        case imageDataCorrupted
    }

    private static var cachePath: URL {
        URL.cachesDirectory.appending(path: "dataImage.png")
    }

    static var cachedImages: UIImage? {
        guard let imageData = try? Data(contentsOf: cachePath) else {
            return  nil
        }
        return UIImage(data: imageData)
    }

    static var cachedImageAvailable: Bool {
        cachedImages != nil
    }
    
    static func fetchMovieDetails(category of: String) async throws -> [UIImage] {
        guard let url = URL(string: "https://api.themoviedb.org/3/trending/\(of)/day?api_key=f393d52a4b88513749207fa6a234dda9") else{
            throw DataFetcherError.imageDataCorrupted
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let detailsData = try JSONDecoder().decode(ResultData.self, from: data)
        var imagesIs = [UIImage]()
        for i in 0..<min(3, detailsData.results.count) {
            if let imageUrl = detailsData.results[i].imageUrl {
                do {
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    let image = UIImage(data: imageData)
                    if let image = image {
                        try? await DataFetcher.cache(imageData)
                        imagesIs.append(image)
                    }
                } catch {
                    throw DataFetcherError.imageDataCorrupted
                }
            }
        }
        return imagesIs
    }
    private static func cache(_ imageData: Data) async throws {
        try imageData.write(to: cachePath)
    }
}
