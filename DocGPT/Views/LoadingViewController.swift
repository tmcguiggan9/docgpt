//
//  LoadingViewController.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 5/8/23.
//

import UIKit

class LoadingViewController: UIViewController {
    var message: String
    
    
    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the background color and alpha of the view
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        
        // Create and add the activity indicator view
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // Create and add the label with the text "Retrieving Chat History"
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        view.addSubview(label)
        
        // Center the activity indicator view and label in the view
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}


