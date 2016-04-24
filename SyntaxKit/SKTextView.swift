//
//  SKTextView.swift
//  SyntaxKit
//
//  Created by Palle Klewitz on 23.04.16.
//  Copyright © 2016 Palle Klewitz. All rights reserved.
//

import UIKit

public class SKTextView: UITextView, NSTextStorageDelegate, UITextViewDelegate
{
	public var language: SKLanguage
	public var autoIndent: Bool = true
	public let lineNumberWidth: CGFloat

	public required init?(coder aDecoder: NSCoder)
	{
		let bundle = NSBundle(forClass: self.dynamicType)
		let dataPath = bundle.pathForResource("Java", ofType: "json")
		let data = NSData(contentsOfFile: dataPath!)
		let language = try! SKLanguage(fromData: data!) 
		self.language = language
		
		lineNumberWidth = 30.0
		
		super.init(coder: aDecoder)
		
		textStorage.delegate = self
		self.delegate = self
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardDidChangeFrame(_:)), name: UIKeyboardDidChangeFrameNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIKeyboardDidHideNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
	}
	
	public override func encodeWithCoder(aCoder: NSCoder)
	{
		super.encodeWithCoder(aCoder)
	}
	
	public override init(frame: CGRect, textContainer: NSTextContainer?)
	{
		let bundle = NSBundle(forClass: self.dynamicType)
		let dataPath = bundle.pathForResource("Java", ofType: "json")
		let data = NSData(contentsOfFile: dataPath!)
		let language = try! SKLanguage(fromData: data!)
		self.language = language
		
		let textStorage = NSTextStorage()
		let layoutManager = SKLayoutManager()
		let textContainer = NSTextContainer(size: CGSize(width: CGFloat.max, height: CGFloat.max))
		textContainer.widthTracksTextView = true
		
		lineNumberWidth = 30.0
		
		let exclusionPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: lineNumberWidth, height: CGFloat.max))
		textContainer.exclusionPaths = [exclusionPath]
		
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		
		super.init(frame: frame, textContainer: textContainer)
		
		textStorage.delegate = self
		self.delegate = self
		
		self.font = UIFont(name: "Menlo", size: 14.0)
		opaque = false
		backgroundColor = UIColor.clearColor()
		autocorrectionType = .No
		autocapitalizationType = .None
		spellCheckingType = .No
		keyboardType = .ASCIICapable
		keyboardAppearance = .Dark
		indicatorStyle = .White
		bounces = true
		alwaysBounceVertical = true
		keyboardDismissMode = .Interactive
		dataDetectorTypes = []
		returnKeyType = .Default
		enablesReturnKeyAutomatically = false
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardDidChangeFrame(_:)), name: UIKeyboardDidChangeFrameNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIKeyboardDidHideNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
	}
	
	public func textStorage(textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int)
	{
		
	}
	
	public func textStorage(textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int)
	{
		textStorage.removeAttribute(NSForegroundColorAttributeName, range: NSRange(location: 0, length: textStorage.length))
		textStorage.addAttribute(NSForegroundColorAttributeName, value: UIColor.whiteColor(), range: NSRange(location: 0, length: textStorage.length))
		
		language.features.forEach
		{ feature in
			do
			{
				let expression = try NSRegularExpression(pattern: feature.pattern, options: [])
				expression.enumerateMatchesInString(self.textStorage.string, options: [], range: NSRange(location: 0, length: self.textStorage.length))
				{ result, flags, stop in
					guard let result = result else { return }
					self.textStorage.addAttribute(NSForegroundColorAttributeName, value: feature.color, range: result.range)
				}
			}
			catch
			{
				print("Expression could not be evaluted. Error: \(error)")
			}
			
		}
	}
	
	public override var keyCommands: [UIKeyCommand]?
	{
		let indentRightCommand = UIKeyCommand(input: "6", modifierFlags: [.Command], action: #selector(indentRight), discoverabilityTitle: "Indent Right")
		let indentLeftCommand = UIKeyCommand(input: "5", modifierFlags: [.Command], action: #selector(indentLeft), discoverabilityTitle: "Indent Left")
		
		let zoomInCommand = UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: [.Command], action: #selector(zoomIn), discoverabilityTitle: "Zoom In")
		let zoomOutCommand = UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: [.Command], action: #selector(zoomOut), discoverabilityTitle: "Zoom Out")
		
		return (super.keyCommands ?? []) + [zoomInCommand, zoomOutCommand, indentLeftCommand, indentRightCommand]
	}
	
	@objc func indentRight()
	{
		guard let newlineExpression = try? NSRegularExpression(pattern: "^(.*?)$", options: [.AnchorsMatchLines])
			else { fatalError("Could not create expression") }
		let newlines = newlineExpression.matchesInString(self.textStorage.string, options: [], range: NSRange(location: 0, length: self.selectedRange.location + self.selectedRange.length))
		let selectedLines = newlines
		.map {$0.range}
		.filter
		{
			NSIntersectionRange($0, self.selectedRange).length > 0
		}
		
		for range in selectedLines.reverse()
		{
			textStorage.insertAttributedString(NSAttributedString(string: "\t"), atIndex: range.location)
		}
		selectedRange.length += selectedLines.count
	}
	
	@objc func indentLeft()
	{
		guard let newlineExpression = try? NSRegularExpression(pattern: "^\t", options: [.AnchorsMatchLines])
			else { fatalError("Could not create expression") }
		let newlines = newlineExpression.matchesInString(self.textStorage.string, options: [], range: NSRange(location: 0, length: selectedRange.location + selectedRange.length))
		let affectedLines = newlines
		.map {$0.range}
		.filter
		{
			NSIntersectionRange($0, self.selectedRange).length > 0
		}
		for range in affectedLines.reverse()
		{
			textStorage.replaceCharactersInRange(NSRange(location: range.location, length: 1), withString: "")
		}
		selectedRange.length -= affectedLines.count
	}
	
	@objc func zoomIn()
	{
		guard let font = self.font else { return }
		self.font = font.fontWithSize(font.pointSize + 1.0)
	}
	
	@objc func zoomOut()
	{
		guard let font = self.font else { return }
		self.font = font.fontWithSize(font.pointSize - 1.0)
	}
	
	@objc func keyboardDidHide(notification: NSNotification)
	{
		guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(), applicationFrame = self.window?.screen.bounds
			else { return }
		let keyboardHeight = applicationFrame.size.height - rect.origin.y
		self.contentInset = UIEdgeInsets(top: self.contentInset.top, left: self.contentInset.left, bottom: keyboardHeight, right: self.contentInset.right)
		self.scrollIndicatorInsets = UIEdgeInsets(top: self.scrollIndicatorInsets.top, left: self.scrollIndicatorInsets.left, bottom: keyboardHeight, right: self.scrollIndicatorInsets.right)
	}
	
	@objc func keyboardWillShow(notification: NSNotification)
	{
		guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(), applicationFrame = self.window?.screen.bounds
			else { return }
		let keyboardHeight = applicationFrame.size.height - rect.origin.y
		self.contentInset = UIEdgeInsets(top: self.contentInset.top, left: self.contentInset.left, bottom: keyboardHeight, right: self.contentInset.right)
		self.scrollIndicatorInsets = UIEdgeInsets(top: self.scrollIndicatorInsets.top, left: self.scrollIndicatorInsets.left, bottom: keyboardHeight, right: self.scrollIndicatorInsets.right)
	}
	
	@objc func keyboardDidChangeFrame(notification: NSNotification)
	{
		guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(), applicationFrame = self.window?.screen.bounds
			else { return }
		let keyboardHeight = applicationFrame.size.height - rect.origin.y
		self.contentInset = UIEdgeInsets(top: self.contentInset.top, left: self.contentInset.left, bottom: keyboardHeight, right: self.contentInset.right)
		self.scrollIndicatorInsets = UIEdgeInsets(top: self.scrollIndicatorInsets.top, left: self.scrollIndicatorInsets.left, bottom: keyboardHeight, right: self.scrollIndicatorInsets.right)
	}
	
	private var previousInsertedText: String?
	private var lastInsertedText: String!
	private var ignore: Bool = false
	
	public func textViewDidChange(textView: UITextView)
	{
		if ignore { return }
		switch lastInsertedText
		{
		case "{":
			ignore = true
			insertText("}")
			ignore = false
			selectedRange.location -= 1
			break
		case "\n":
			if let previousInsertedText = previousInsertedText
				where previousInsertedText == "{"
				|| previousInsertedText == "("
				|| previousInsertedText == "["
			{
				ignore = true
				let indentationLevel = self.indentationLevel(atLocation: selectedRange.location)
				insertText("\t".repeated(max(indentationLevel, 0)))
				insertText("\n")
				insertText("\t".repeated(max(indentationLevel-1, 0)))
				ignore = false
				selectedRange.location -= indentationLevel
			}
			else
			{
				let indentationLevel = self.indentationLevel(atLocation: selectedRange.location)
				ignore = true
				insertText("\t".repeated(max(indentationLevel, 0)))
				ignore = false
			}
			break
		case "(":
			ignore = true
			insertText(")")
			ignore = false
			selectedRange.location -= 1
			break
		case "[":
			ignore = true
			insertText("]")
			ignore = false
			selectedRange.location -= 1
			break
		case "\"":
			ignore = true
			insertText("\"")
			ignore = false
			selectedRange.location -= 1
			break
		case "'":
			ignore = true
			insertText("'")
			ignore = false
			selectedRange.location -= 1
			break
		case "*":
			ignore = true
			if (textStorage.string as NSString).substringWithRange(NSRange(location: selectedRange.location-2, length: 1)) == "/"
			{
				insertText("*/")
				selectedRange.location -= 2
			}
			ignore = false
			break
		default:
			break
		}
		
		previousInsertedText = lastInsertedText
	}
	
	public func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool
	{
		if !ignore
		{
			if textStorage.length > range.location
			{
				let nextCharacter = (textStorage.string as NSString).substringWithRange(NSRange(location: range.location, length: 1))
				switch (text, nextCharacter)
				{
				case ("}", "}"):
					selectedRange.location += 1
					return false
				case ("]", "]"):
					selectedRange.location += 1
					return false
				case (")", ")"):
					selectedRange.location += 1
					return false
				case ("\"", "\""):
					selectedRange.location += 1
					return false
				case ("'", "'"):
					selectedRange.location += 1
					return false
				default:
					break
				}
			}
			
			lastInsertedText = text
		}
		else
		{
			lastInsertedText = ""
		}
		//TODO: detect tabs and ignore them if a placeholder exists.
		return true
	}
	
	func indentationLevel(atLocation location: Int) -> Int
	{
		//TODO: Search for quotes and stuff to ignore brackets if in a string.
		guard
			let increaseExpression = try? NSRegularExpression(pattern: "\\{|\\[|\\(", options: []),
			let decreaseExpression = try? NSRegularExpression(pattern: "\\}|\\]|\\)", options: [])
		else { fatalError("Invalid regex") }
		
		let textRange = NSRange(location: 0, length: location)
		
		let increasingMatchCount = increaseExpression.numberOfMatchesInString(textStorage.string, options: [], range: textRange)
		let decreasingMatchCount = decreaseExpression.numberOfMatchesInString(textStorage.string, options: [], range: textRange)
		
		return increasingMatchCount - decreasingMatchCount
	}

}