//
//  ViewController.swift
//  UserInteractiveWidget
//
//  Created by Harsha R Mundaragi  on 18/10/23.
//

import UIKit
import Alamofire
import Combine
import SDWebImage




class TableViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageToShow: UIImageView!
    func renderCell(render with: AllDetails){
        imageToShow.layer.cornerRadius = 15
        self.contentView.backgroundColor = .systemGray4
        self.layer.masksToBounds = true
        self.contentView.layer.cornerRadius = 15
        guard let url = with.imageUrl else{
            return
        }
        imageToShow.sd_setImage(with: url)
    }
    
}

class ViewController: UIViewController, URLHandlingDelegate {
    
    func handleURLResult(_ result: String) {
        callTheAPi(with: result)
    }
    

    @IBOutlet weak var collectionView01: UICollectionView!
    var cancelable: [AnyCancellable] = []
    var resultdata = [AllDetails]()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView01.delegate = self
        collectionView01.dataSource = self
        callTheAPi(with: "all")
    }
    
    
    private func callTheAPi(with: String){
        NetworkManager.networkCall(with: with)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion{
                case .finished:
                    print("fishished")
                case .failure(let error):
                    print(error)
                }
        }, receiveValue: { [weak self] result in
            self?.resultdata = result
            self?.collectionView01.reloadData()
        }).store(in: &cancelable)
    }


}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return resultdata.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let render = resultdata[indexPath.row]
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? TableViewCell else{
            return UICollectionViewCell()
        }
        cell.renderCell(render: render)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: (collectionView.frame.width - 10) / 2, height: (collectionView.frame.height) / 2.5)
    }
    
}

//"https://image.tmdb.org/t/p/w500\(poster_path)"



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


final class NetworkManager{
    static let shared = NetworkManager()
    private init() { }
    
    static func networkCall(with: String) -> Future<[AllDetails], Error> {
        return Future{ promise in
            guard let url = URL(string: "https://api.themoviedb.org/3/trending/\(with)/day?api_key=f393d52a4b88513749207fa6a234dda9") else{
                promise(.failure(FailureCases.failedToFetch))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                guard let data = data, error == nil else{
                    promise(.failure(FailureCases.failedToFetch))
                    return
                }
                do {
                    let resultData = try JSONDecoder().decode(ResultData.self, from: data)
                    promise(.success(resultData.results))
                } catch {
                    promise(.failure(FailureCases.failedToFetch))
                    print("catch error")
                }
            })
            task.resume()
        }
    }
    
    enum FailureCases: Error{
        case failedToFetch
    }
}

