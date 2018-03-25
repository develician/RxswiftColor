//
//  ViewController.swift
//  RxSwiftColor
//
//  Created by 최동호 on 2018. 3. 25..
//  Copyright © 2018년 최동호. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ColorViewController: UIViewController {

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var hexColorTextField: UITextField!
    @IBOutlet weak var applyButton: UIButton!
    
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    
    @IBOutlet weak var rSlider: UISlider!
    @IBOutlet weak var gSlider: UISlider!
    @IBOutlet weak var bSlider: UISlider!
    
    @IBOutlet weak var savedColorView: UIView!
    
    
    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bind()
    }



}


extension ColorViewController {
    func bind() {
        let color = Observable.combineLatest(rSlider.rx.value, gSlider.rx.value, bSlider.rx.value) { (redValue, greenValue, blueValue) -> UIColor in
            UIColor(red: CGFloat(redValue), green: CGFloat(greenValue), blue: CGFloat(blueValue), alpha: 1)
        }
        
        color.subscribe(onNext: { [weak self] (color: UIColor) in
            self?.colorView.backgroundColor = color
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        color.map { (color: UIColor) -> String in
            color.hexString
            }.subscribe(onNext: { [weak self] (colorString: String) in
                self?.hexColorTextField.text = colorString
            }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        applyButton.rx.tap.asObservable().withLatestFrom(self.hexColorTextField.rx.text)
            .map { (hexText: String?) -> (Int, Int, Int)? in
                return hexText?.rgb
            }.filter { rgb -> Bool in
                return rgb != nil
            }.map{ $0! }
            .subscribe(onNext: { [weak self] (red, green, blue) in
                self?.rSlider.rx.value.onNext(Float(red) / 255.0)
                self?.rSlider.sendActions(for: .valueChanged)
                self?.gSlider.rx.value.onNext(Float(green) / 255.0)
                self?.gSlider.sendActions(for: .valueChanged)
                self?.bSlider.rx.value.onNext(Float(blue) / 255.0)
                self?.bSlider.sendActions(for: .valueChanged)
                
                self?.view.endEditing(true)
                
            }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        
        saveButton.rx.tap.asObservable().withLatestFrom(colorView.rx.observe(UIColor.self, "backgroundColor")).map { $0! }
            .flatMap { (color: UIColor) -> Observable<UIColor> in
                return ColorArchiveAPI.instance.save(color: color)
            }.subscribe(onNext: { [weak self] (savedColor: UIColor) in
                self?.savedColorView.backgroundColor = savedColor
            }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        loadButton.rx.tap.asObservable().flatMap { _ -> Observable<UIColor> in
            return ColorArchiveAPI.instance.load()
            }.subscribe(onNext: { [weak self] (savedColor: UIColor) in
                self?.hexColorTextField.rx.text.onNext(savedColor.hexString)
                self?.hexColorTextField.sendActions(for: .valueChanged)
                self?.applyButton.sendActions(for: .touchUpInside)
            }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        ColorArchiveAPI.instance.load()
            .subscribe(onNext: { [weak self] (color) in
                self?.savedColorView.backgroundColor = color
            }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
}

extension Reactive where Base: ColorViewController {
    static func create(parent: UIViewController?, animated: Bool = true) -> Observable<ColorViewController> {
        return Observable.create({ [weak parent] (observer) -> Disposable in
            let colorViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ColorViewController") as! ColorViewController
            let dismissDisposable = colorViewController.cancelButton.rx.tap.subscribe(onNext: {
                [weak colorViewController] _ in
                guard let colorViewController = colorViewController else {
                    return
                }
                colorViewController.dismiss(animated: true, completion: nil)
            })
            
            let navController = UINavigationController(rootViewController: colorViewController)
            parent?.present(navController, animated: true, completion: {
                observer.onNext(colorViewController)
            })
            
            return Disposables.create(dismissDisposable, Disposables.create {
                colorViewController.dismiss(animated: animated, completion: nil)
            })
        })
    }
    var selectedColor: Observable<UIColor> {
        return base.doneButton.rx.tap.withLatestFrom(base.colorView.rx.observe(UIColor.self, "backgroundColor")).map { $0! }
    }
}


extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%.2X%.2X%.2X", Int(255 * red), Int(255 * green), Int(255 * blue))
    }
}



extension String {
    var rgb: (Int, Int, Int)? {
        guard let number: Int = Int(self, radix: 16) else {
            return nil
        }
        let blue = number & 0x0000ff
        let green = (number & 0x00ff00) >> 8
        let red = (number & 0xff0000) >> 16
        return (red, green, blue)
    }
}


class ColorArchiveAPI {
    static let instance: ColorArchiveAPI = ColorArchiveAPI()
    var color: UIColor? = nil
    
    func save(color: UIColor) -> Observable<UIColor> {
        self.color = color
        return Observable.just(color).delay(0.7, scheduler: MainScheduler.instance)
    }
    
    func load() -> Observable<UIColor> {
        guard let color = color else {
            return Observable.empty().delay(0.7, scheduler: MainScheduler.instance)
        }
        return Observable.just(color).delay(0.7, scheduler: MainScheduler.instance)
    }
}



