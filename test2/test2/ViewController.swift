//
//  ViewController.swift
//  test2
//
//  Created by huy on 7/14/23.
//

import UIKit
import AVFoundation
import AVKit
import MobileCoreServices
import FFmpegKit


class ViewController: UIViewController {
    
    
    @IBOutlet weak var table_View1: UITableView!
    
    var links: [(name: String, date: String, type: String, url: URL)] = []
    let userDefaults = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let fileManager = FileManager.default
        guard let documentsFolderURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        print(documentsFolderURL)
        
        table_View1.register(UITableViewCell.self, forCellReuseIdentifier: "tableView")
        
        table_View1.reloadData()
    }
    
    func saveLinks() {
        let fileManager = FileManager.default
        guard let documentsFolderURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURLs = try? fileManager.contentsOfDirectory(at: documentsFolderURL, includingPropertiesForKeys: nil)
        let fileNames = fileURLs?.map { $0.lastPathComponent }
        userDefaults.set(fileNames, forKey: "fileName")
    }
    
    func loadLinks() {
        guard let fileNames = userDefaults.array(forKey: "fileName") as? [String] else {
            return
        }
        let fileManager = FileManager.default
        guard let documentsFolderURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
//        print("Mac dinh : \(documentsFolderURL)")
        
        for fileName in fileNames {
            let fileURL = documentsFolderURL.appendingPathComponent(fileName)
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let creationDate = attributes?[.creationDate] as? Date ?? Date()
            let type = fileURL.pathExtension.lowercased()
            links.append((name: fileName, date: DateFormatter.localizedString(from: creationDate, dateStyle: .medium, timeStyle: .medium), type: type, url: fileURL))
        }
    }
    
    func copyFileToDocumentsFolder(sourceURL: URL, destinationURL: URL, fileName: String) throws ->String {
        let fileManager = FileManager.default
    
        // Tạo thư mục Documents nếu nó chưa tồn tại
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let destinationFilePath = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        // Kiểm tra nếu file đã tồn tại trong Documents thì sửa đổi tên file đó và lưu lại
        if fileManager.fileExists(atPath: destinationFilePath.path) {
            let fileNameWithoutExtension = sourceURL.lastPathComponent.components(separatedBy: ".").first ?? "file"
            let fileExtension = sourceURL.pathExtension
            var newFileName = "\(fileNameWithoutExtension) (copy).\(fileExtension)"
            var fileNumber = 1
            while fileManager.fileExists(atPath: destinationURL.appendingPathComponent(newFileName).path) {
                fileNumber += 1
                newFileName = "\(fileNameWithoutExtension) (copy \(fileNumber)).\(fileExtension)"
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL.appendingPathComponent(newFileName))
            return newFileName
        } else {
            // Copy file vào thư mục Documents nếu file chưa tồn tại trong thư mục đó
            try fileManager.copyItem(at: sourceURL, to: destinationFilePath)
        }
        
        return fileName
    }


    
    
    @IBAction func extractAudioAndExport(_ sender: UIButton) {
        let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [kUTTypeMovie as String]
            present(picker, animated: true)
        
    }

    
    
    
    
    
}

extension ViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return links.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
     
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tableView", for: indexPath) as? UITableViewCell else {
            return UITableViewCell()
        }
        
        cell.textLabel?.text = links[indexPath.row].name
        cell.detailTextLabel?.text = links[indexPath.row].date
        cell.detailTextLabel?.text = links[indexPath.row].url.path
        return cell
    }
    
}


extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)

        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
              mediaType == (kUTTypeMovie as String),
              let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
            return
        }
        let documentsFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsFolderURL.appendingPathComponent(url.lastPathComponent)
        do {
            let fileName = try copyFileToDocumentsFolder(sourceURL: url, destinationURL: documentsFolderURL, fileName: url.lastPathComponent)
            let type = url.pathExtension.lowercased()
            links.append((name: fileName, date: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium), type: type, url: destinationURL))
            table_View1.reloadData()
            saveLinks()
        } catch {
            print(error.localizedDescription)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedLink = links[indexPath.row].url
        
//        let videoURL = URL(fileURLWithPath: selectedLink)
        extractAudio(from: selectedLink) { audioURL in
            if let audioURL = audioURL {
                print("Extracted audio file: \(audioURL.path)")
                // Xử lý tệp âm thanh sau khi trích xuất
            } else {
                print("Failed to extract audio from video.")
            }
        }

    }

    func extractAudio(from videoURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)

        guard let session = exportSession else {
            completion(nil)
            return
        }

        // Create directory path for ExtractedAudio
        let fileManager = FileManager.default
        let directoryPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("ExtractedAudio")

        // Check if ExtractedAudio directory exists, if not, create it
        if let directoryPath = directoryPath {
            if !fileManager.fileExists(atPath: directoryPath.path) {
                do {
                    try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    completion(nil)
                    return
                }
            }
        }

        let alertController = UIAlertController(title: "Enter File Name", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "File Name"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { (_) in
            guard let fileName = alertController.textFields?.first?.text else {
                completion(nil)
                return
            }

            let fileExtension = ".m4a"
            var outputFileName = fileName + fileExtension
            var outputURL = directoryPath?.appendingPathComponent(outputFileName)

            // Check if file already exists, modify the name with a unique number appended to the extension
            var fileNumber = 1
            while fileManager.fileExists(atPath: outputURL?.path ?? "") {
                outputFileName = "\(fileName)_\(fileNumber)" + fileExtension
                outputURL = directoryPath?.appendingPathComponent(outputFileName)
                fileNumber += 1
            }

            session.outputFileType = .m4a
            session.outputURL = outputURL

            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    completion(outputURL)
                case .failed, .cancelled:
                    completion(nil)
                default:
                    break
                }
            }
        }

        alertController.addAction(saveAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            completion(nil)
        }

        alertController.addAction(cancelAction)

        // Present the UIAlertController
        if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
            topViewController.present(alertController, animated: true, completion: nil)
        }
    }

 

//    func extractAudio(from videoURL: URL, completion: @escaping (URL?) -> Void) {
//        let asset = AVURLAsset(url: videoURL)
//        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
//
//        guard let session = exportSession else {
//            completion(nil)
//            return
//        }
//
//        // Create directory path for ExtractedAudio
//        let fileManager = FileManager.default
//        let directoryPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("ExtractedAudio")
//
//        // Check if ExtractedAudio directory exists, if not, create it
//        if let directoryPath = directoryPath {
//            if !fileManager.fileExists(atPath: directoryPath.path) {
//                do {
//                    try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
//                } catch {
//                    completion(nil)
//                    return
//                }
//            }
//        }
//
//        let alertController = UIAlertController(title: "Enter File Name", message: nil, preferredStyle: .alert)
//        alertController.addTextField { (textField) in
//            textField.placeholder = "File Name"
//        }
//
//        let saveAction = UIAlertAction(title: "Save", style: .default) { (_) in
//            guard let fileName = alertController.textFields?.first?.text else {
//                completion(nil)
//                return
//            }
//
//            let fileExtension = ".m4a"
//
//            var outputFileName = fileName + fileExtension
//            var outputURL = directoryPath?.appendingPathComponent(outputFileName)
//
//            // Check if file already exists, modify the name with a unique number appended to the extension
//            var fileNumber = 1
//            while fileManager.fileExists(atPath: outputURL?.path ?? "") {
//                outputFileName = "\(fileName)_\(fileNumber)" + fileExtension
//                outputURL = directoryPath?.appendingPathComponent(outputFileName)
//                fileNumber += 1
//            }
//
//            session.outputFileType = .m4a
//            session.outputURL = outputURL
//
//            session.exportAsynchronously {
//                switch session.status {
//                case .completed:
//                    // Convert the output file to MP3
//                    let mp3OutputURL = directoryPath?.appendingPathComponent(fileName + ".mp3")
//
//                    let executionFactory = FFmpegKitConfig.getFFmpegKitExecuteDelegate()
//                    let arguments = ["-i", outputURL?.path ?? "", mp3OutputURL?.path ?? ""]
//
//                    let executionId = FFmpegKit.executeAsync(arguments, withExecuteDelegate: executionFactory) { session in
//                        if session?.getState() == .completed {
//                            completion(mp3OutputURL)
//                        } else {
//                            completion(nil)
//                        }
//                    }
//
//                    if executionId == Constants.FFEXECUTION_ID_NONE {
//                        completion(nil)
//                    }
//                case .failed, .cancelled:
//                    completion(nil)
//                default:
//                    break
//                }
//            }
//        }
//
//        alertController.addAction(saveAction)
//
//        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
//            completion(nil)
//        }
//
//        alertController.addAction(cancelAction)
//
//        // Present the UIAlertController
//        if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
//            topViewController.present(alertController, animated: true, completion: nil)
//        }
//    }

}


