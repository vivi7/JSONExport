//
//  ViewController.swift
//  JSONExport
//
//	Create by Vincenzo Favara on 24/04/2016
//	Copyright © 2016 Vincenzo Favara. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the contributor can not be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
//  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//   SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
//  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
//  OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Cocoa
import Alamofire
//import SwiftyJSON

class ViewController: NSViewController{
    
    //Shows the list of files' preview
    @IBOutlet weak var tableView: NSTableView!
    
    //Connected to the top right corner to show the current parsing status
    @IBOutlet weak var statusTextField: NSTextField!
    
    //Connected to the save button
    @IBOutlet weak var saveButton: NSButton!
    
    //Connected to the scroll view which wraps the sourceText
    @IBOutlet weak var scrollView: NSScrollView!
    
    //Connected to Constructors check box
    @IBOutlet weak var generateConstructors: NSButtonCell!
    
    //Connected to Utility Methods check box
    @IBOutlet weak var generateUtilityMethods: NSButtonCell!
    
    //Connected to root class name field
    @IBOutlet weak var classNameField: NSTextFieldCell!
    
    //Connected to parent class name field
    @IBOutlet weak var parentClassName: NSTextField!
    
    //Connected to class prefix field
    @IBOutlet weak var classPrefixField: NSTextField!
    
    //Connected to the first line statement field
    @IBOutlet weak var firstLineField: NSTextField!
    
    //Connected to the languages pop up
    @IBOutlet weak var languagesPopup: NSPopUpButton!
    
    //Connected to the JSON input text view
    @IBOutlet var sourceText: NSTextView!
    
    //Connect to the url for getting remote json
    @IBOutlet weak var urlTextField: NSTextField!
    
    //Connect to body params to the url for getting remote json
    @IBOutlet var bodyTextField: NSTextView!
    
    //Connect to header params to the url for getting remote json
    @IBOutlet var headerTextField: NSTextView!
    
    //Connect to method to the url for getting remote json
    @IBOutlet var methodPopUpButton: NSPopUpButton!
    
    //Connect to the description error
    @IBOutlet var descriptionErrorLabel: NSTextField!
    
    //Connect to result for the url for getting remote json
    @IBOutlet var apiProgressIndicator: NSProgressIndicator!
    
    //Connect to current position inside textfield
    @IBOutlet var cursorPositionLabel: NSTextField!
    
    //Connect to json formatter checks
    @IBOutlet var jsonBodyFormatterCheck: NSButtonCell!
    @IBOutlet var jsonHeaderFormatterCheck: NSButtonCell!
    @IBOutlet var jsonSourceFormatterCheck: NSButtonCell!
    
    
    //Holds the currently selected language
    var selectedLang : LangModel!
    
    var dictMethodAlamofire = Dictionary<String, Alamofire.Method>()
    
    //Returns the title of the selected language in the languagesPopup
    var selectedLanguageName : String
        {
        return languagesPopup.titleOfSelectedItem!
    }
    
    //Should hold list of supported languages, where the key is the language name and the value is LangModel instance
    var langs : [String : LangModel] = [String : LangModel]()
    
    //Holds list of the generated files
    var files : [FileRepresenter] = [FileRepresenter]()
    
    private enum field : String{
        case body, header, source
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //TODO: remove when formatters are ready
        jsonBodyFormatterCheck.controlView?.hidden = true
        jsonHeaderFormatterCheck.controlView?.hidden = true
        jsonSourceFormatterCheck.controlView?.hidden = true
        
        
        
        sourceText.delegate = self
        headerTextField.delegate = self
        bodyTextField.delegate = self
        
        prepareGraphic()
        
        loadSupportedLanguages()
        setupNumberedTextView()
        setLanguagesSelection()
        updateUIFieldsForSelectedLanguage()
        loadMethodPopUpButton()
    }
    
    /**
    Sets the values of languagesPopup items' titles
    */
    func setLanguagesSelection()
    {
        let langNames = Array(langs.keys).sort()
        languagesPopup.removeAllItems()
        languagesPopup.addItemsWithTitles(langNames)
        
    }
    
    /**
    Sets the needed configurations for show the line numbers in the input text view
    */
    func setupNumberedTextView()
    {
        let lineNumberView = NoodleLineNumberView(scrollView: scrollView)
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = lineNumberView
        scrollView.rulersVisible = true
        sourceText.font = NSFont.userFixedPitchFontOfSize(NSFont.smallSystemFontSize())
        
    }
    
    /**
    Updates the visible fields according to the selected language
    */
    func updateUIFieldsForSelectedLanguage()
    {
        loadSelectedLanguageModel()
        if selectedLang.supportsFirstLineStatement != nil && selectedLang.supportsFirstLineStatement!.boolValue{
            firstLineField.hidden = false
            firstLineField.placeholderString = selectedLang.firstLineHint
        }else{
            firstLineField.hidden = true
        }
        
        if selectedLang.modelDefinitionWithParent != nil || selectedLang.headerFileData?.modelDefinitionWithParent != nil{
            parentClassName.hidden = false
        }else{
            parentClassName.hidden = true
        }
    }
    
    
    
    //MARK: - Handling pre defined languages
    func loadSupportedLanguages(){
        if let langFiles = NSBundle.mainBundle().URLsForResourcesWithExtension("json", subdirectory: nil) as [NSURL]!{
            for langFile in langFiles{
                if let data = NSData(contentsOfURL: langFile), langDictionary = (try? NSJSONSerialization.JSONObjectWithData(data, options: [])) as? NSDictionary{
                    let lang = LangModel(fromDictionary: langDictionary)
                    if langs[lang.displayLangName] != nil{
                        continue
                    }
                    langs[lang.displayLangName] = lang
                }
                
                
            }
        }
        
    }

    
    
    //MARK: - Handlind events
    
    @IBAction func toggleConstructors(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }
    
    
    @IBAction func toggleUtilities(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }
    
    @IBAction func rootClassNameChanged(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }
    
    @IBAction func parentClassNameChanged(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }
    
    
    @IBAction func classPrefixChanged(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }
    
    
    @IBAction func selectedLanguageChanged(sender: AnyObject){
        updateUIFieldsForSelectedLanguage()
        validateAndGenerateClasses(field.source.rawValue);
    }
    
    
    @IBAction func firstLineChanged(sender: AnyObject){
        validateAndGenerateClasses(field.source.rawValue)
    }

    @IBAction func urlLineChanged(sender: NSTextField) {
        callJson()
    }
    
    
    @IBAction func jsonSourceFormatterAction(sender: NSButtonCell) {
        jsonFormatter(field.source.rawValue)
    }
    
    @IBAction func jsonBodyFormatterAction(sender: NSButtonCell) {
        jsonFormatter(field.body.rawValue)
    }
    
    @IBAction func jsonHeaderFormatterAction(sender: NSButtonCell) {
        jsonFormatter(field.header.rawValue)
    }
    
    //MARK: - Showing the open panel and save files
    @IBAction func saveFiles(sender: AnyObject)
    {
        let openPanel = NSOpenPanel()
        openPanel.allowsOtherFileTypes = false
        openPanel.treatsFilePackagesAsDirectories = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Choose"
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: { (button : Int) -> Void in
            if button == NSFileHandlingPanelOKButton{
                self.saveToPath(openPanel.URL!.path!)
                self.showDoneSuccessfully()
            }
        })
    }
    
    func prepareGraphic(){
        self.saveButton.enabled = false
        self.apiProgressIndicator.layer?.cornerRadius = self.apiProgressIndicator.layer!.frame.height/2
    }
    
    func loadMethodPopUpButton(){
        methodPopUpButton.removeAllItems()
        var keyToDispaly : [String] = []
        for method in iterateEnum(Alamofire.Method){
            dictMethodAlamofire.updateValue(method, forKey: method.rawValue)
            keyToDispaly.append(method.rawValue)
        }
        methodPopUpButton.addItemsWithTitles(keyToDispaly)
    }
    
    func iterateEnum<T: Hashable>(_: T.Type) -> AnyGenerator<T> {
        var i = 0
        return AnyGenerator {
            let next = withUnsafePointer(&i) { UnsafePointer<T>($0).memory }
            return next.hashValue == (i++) ? next : nil
        }
    }
    
    func callJson() {
        
        if urlTextField.stringValue.characters.count < 3 {
            return
        }
//        let httpProtStart = "http://"
//        if !urlTextField.stringValue.containsString(httpProtStart){
//            urlTextField.stringValue = httpProtStart
//        }
        
        let jsonBody = validateJSON(bodyTextField)
        if jsonBody == nil {
            return
        }
        
        let jsonHeader = validateJSON(headerTextField)
        if jsonHeader == nil {
            return
        }
        
        let method = dictMethodAlamofire[methodPopUpButton.titleOfSelectedItem!]!
        
        let url = urlTextField.stringValue
        
        self.apiProgressIndicator.layer?.backgroundColor = NSColor.grayColor().CGColor
        Alamofire.request(method, url,
            parameters: jsonBody as? [String : AnyObject], encoding: .JSON, headers: jsonHeader as? [String:String])
            .response { request, response, data, error in
                if error == nil{
                    self.apiProgressIndicator.layer?.backgroundColor = NSColor.greenColor().CGColor
                    
                    self.sourceText.string = self.sourceText.string?.jsonStringPrettyPrintedFromData(data!)
                    self.sourceText.didChangeText()
                    //                    do {
                    //                        let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
                    //                        let dataJson = try NSJSONSerialization.dataWithJSONObject(json, options: .PrettyPrinted)
                    //                        self.sourceText.string = NSString(data: dataJson, encoding: NSUTF8StringEncoding) as? String
                    //                        self.sourceText.didChangeText()
                    //                    } catch let error1 as NSError {
                    //                        self.apiProgressIndicator.layer?.backgroundColor = NSColor.redColor().CGColor
                    //                        self.descriptionErrorLabel.stringValue = error1.localizedDescription
                    //                    }
                } else {
                    self.apiProgressIndicator.layer?.backgroundColor = NSColor.redColor().CGColor
                    self.descriptionErrorLabel.stringValue = error!.localizedDescription
                }
        }
        return
    }
    
    /**
    Saves all the generated files in the specified path
    
    - parameter path: in which to save the files
    */
    func saveToPath(path : String)
    {
        var error : NSError?
        for file in files{
            let fileContent = file.fileContent
            var fileExtension = selectedLang.fileExtension
            if file is HeaderFileRepresenter{
                fileExtension = selectedLang.headerFileData.headerFileExtension
            }
            let filePath = "\(path)/\(file.className).\(fileExtension)"
            
            do {
                try fileContent.writeToFile(filePath, atomically: false, encoding: NSUTF8StringEncoding)
            } catch let error1 as NSError {
                error = error1
            }
            if error != nil{
                showError(error!)
                break
            }
            
        }
    }
    
    
    //MARK: - Messages
    /**
    Shows the top right notification. Call it after saving the files successfully
    */
    func showDoneSuccessfully()
    {
        let notification = NSUserNotification()
        notification.title = "Success!"
        notification.informativeText = "Your \(selectedLang.langName) model files have been generated successfully."
        notification.deliveryDate = NSDate()

        let center = NSUserNotificationCenter.defaultUserNotificationCenter()
        center.delegate = self
        center.deliverNotification(notification)
    }
    
    /**
    Shows an NSAlert for the passed error
    */
    func showError(error: NSError!)
    {
        if error == nil{
            return;
        }
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    
    /**
    Shows the passed error status message
    */
    func showErrorStatus(errorMessage: String)
    {

        statusTextField.textColor = NSColor.redColor()
        statusTextField.stringValue = errorMessage
    }
    
    /**
    Shows the passed success status message
    */
    func showSuccessStatus(successMessage: String)
    {
        
        statusTextField.textColor = NSColor.greenColor()
        statusTextField.stringValue = successMessage
    }
    
    
    //MARK: - Validate JSON
    
    func validateJSON(field: NSTextView) -> AnyObject? {
        let jsonString = field.string!
        descriptionErrorLabel.stringValue = ""
        if jsonString.characters.count == 0{
            //Nothing to do, just clear any generated files
            files.removeAll(keepCapacity: false)
            //tableView.reloadData()
            return ""
        }
        
        let str = jsonStringByRemovingUnwantedCharacters(jsonString)
        if let data = str.dataUsingEncoding(NSUTF8StringEncoding){
            do {
                let jsonData : AnyObject = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                self.reloadUIAndMessage(true)
                self.jsonFormatter(field.identifier!)
                return jsonData
            } catch  let error as NSError{
                let errorStr = error.userInfo
                descriptionErrorLabel.stringValue = errorStr.description.stringByReplacingOccurrencesOfString("NSDebugDescription: ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            }
        }
        self.reloadUIAndMessage(false)
        return nil
    }
    
    
    //MARK: - Display
    
    func reloadUIAndMessage(isGenerated: Bool){
        runOnUiThread({ () -> Void in
            //self.sourceText.editable = true
            if isGenerated{
                self.showSuccessStatus("Valid JSON structure")
            } else {
                self.showErrorStatus("It seems your JSON object is not valid!")
            }
        })
    }
    
    //MARK: - Generate files content
    /**
    Validates the sourceText string input, and takes any needed action to generate the model classes and view them in the preview panel
    */
    func validateAndGenerateClasses(identifier: String) {
        switch identifier{
        case field.source.rawValue:
            generateClassesWithJson(validateJSON(sourceText!))
        case field.body.rawValue:
            validateJSON(bodyTextField!)
        case field.header.rawValue:
            validateJSON(headerTextField!)
        default:
            validateJSON(bodyTextField)
            validateJSON(headerTextField)
            generateClassesWithJson(validateJSON(sourceText!))
        }
        
    }
    
    func generateClassesWithJson(jsonData : AnyObject?) {
        saveButton.enabled = false
        self.tableView.reloadData()
        if jsonData == nil || jsonData is String{
            return
        }
        apiProgressIndicator.layer?.backgroundColor = NSColor.clearColor().CGColor
        runOnBackground {
            var json : NSDictionary!
            if jsonData is NSDictionary{
                //fine nothing to do
                json = jsonData as! NSDictionary
            }else{
                json = unionDictionaryFromArrayElements(jsonData as! NSArray)
            }
            self.generateClassesCore(json)
            //self.sourceText.string = self.sourceText.string?.jsonStringPrettyPrinted()
            self.tableView.reloadData()
            self.saveButton.enabled = true
        }
    }
    
    func generateClassesCore(json:NSDictionary){
        self.loadSelectedLanguageModel()
        self.files.removeAll(keepCapacity: false)
        let fileGenerator = self.prepareAndGetFilesBuilder()
        var rootClassName = self.classNameField.stringValue
        if rootClassName.characters.count == 0{
            rootClassName = "RootClass"
        }
        fileGenerator.addFileWithName(&rootClassName, jsonObject: json, files: &self.files)
        fileGenerator.fixReferenceMismatches(inFiles: self.files)
        self.files = Array(self.files.reverse())
    }
    
    //MARK: - Formatter JSON
    func jsonFormatter(identifier: String) {
        switch identifier{
        case field.source.rawValue:
            if jsonSourceFormatterCheck.state == NSOnState{
                sourceText!.string = sourceText!.string!.jsonStringPrettyPrinted()
            }
        case field.body.rawValue:
            if jsonBodyFormatterCheck.state == NSOnState{
                bodyTextField!.string = bodyTextField!.string!.jsonStringPrettyPrinted()
            }
        case field.header.rawValue:
            if jsonHeaderFormatterCheck.state == NSOnState{
                headerTextField!.string = headerTextField!.string!.jsonStringPrettyPrinted()
            }
        default:
            if jsonSourceFormatterCheck.state == NSOnState{
                sourceText!.string = sourceText!.string!.jsonStringPrettyPrinted()
            }
            if jsonBodyFormatterCheck.state == NSOnState{
                bodyTextField!.string = bodyTextField!.string!.jsonStringPrettyPrinted()
            }
            if jsonHeaderFormatterCheck.state == NSOnState{
                headerTextField!.string = headerTextField!.string!.jsonStringPrettyPrinted()
            }
        }
        
    }
    
    //MARK: - Language selection handling
    func loadSelectedLanguageModel(){
        selectedLang = langs[selectedLanguageName]
    }
    
    /**
    Creates and returns an instance of FilesContentBuilder. It also configure the values from the UI components to the instance. I.e includeConstructors
    
    - returns: instance of configured FilesContentBuilder
    */
    func prepareAndGetFilesBuilder() -> FilesContentBuilder
    {
        let filesBuilder = FilesContentBuilder.instance
        filesBuilder.includeConstructors = (generateConstructors.state == NSOnState)
        filesBuilder.includeUtilities = (generateUtilityMethods.state == NSOnState)
        filesBuilder.firstLine = firstLineField.stringValue
        filesBuilder.lang = selectedLang
        filesBuilder.classPrefix = classPrefixField.stringValue
        filesBuilder.parentClassName = parentClassName.stringValue
        return filesBuilder
    }
    
}

extension ViewController : NSTableViewDelegate, NSTableViewDataSource{
    //MARK: - NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int
    {
        return files.count
    }
    
    
    //MARK: - NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        let cell = tableView.makeViewWithIdentifier("fileCell", owner: self) as! FilePreviewCell
        let file = files[row]
        cell.file = file
        
        return cell
    }
}

extension ViewController : NSUserNotificationCenterDelegate{
    
    //MARK: - NSUserNotificationCenterDelegate
    func userNotificationCenter(center: NSUserNotificationCenter,
                                shouldPresentNotification notification: NSUserNotification) -> Bool{
        return true
    }
}

extension ViewController : NSTextViewDelegate{
    
    //MARK: - NSTextDelegate
    
    func textDidChange(notification: NSNotification) {
        validateAndGenerateClasses(notification.object!.identifier!)
    }
    
    func textViewDidChangeSelection(notification: NSNotification) {
        let range = notification.userInfo!.first!.1
        cursorPositionLabel.stringValue = range.description.stringByReplacingOccurrencesOfString("NSRange", withString: "Position", options: NSStringCompareOptions.LiteralSearch, range: nil)
    }
}


