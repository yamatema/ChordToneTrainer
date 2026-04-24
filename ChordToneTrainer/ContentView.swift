//
//  ContentView.swift
//  ChordToneTrainer
//
//  Created by Yamamoto Takuya on 2026/03/14.
//

import SwiftUI

enum ToneRole: String {
    case root = "root"
    case third = "3rd"
    case fifth = "5th"
    case seventh = "7th"
    //case ninth = "9th"
    //case eleventh = "11th"
    //case thirteenth = "13th"
}

extension ToneRole {
    var color: Color {
        switch self {
        case .root: return .gray
        case .third: return .blue
        case .fifth: return .gray
        case .seventh: return .red
        //case .ninth: return .indigo
        //case .eleventh: return .brown
        //case .thirteenth: return .pink
        
        }
    }
}



struct ChordType: Equatable, Hashable {
    let name: String
    let intervals: [Int]
}

struct Chord: Equatable, Hashable {
    let root: String
    let type: ChordType
}

struct IIVIProgression {
    let ii: String
    let v: String
    let i: String
    let root: String
    let chordType: ChordType
}

struct ButtonStylePalette {
    let background: Color
    let foreground: Color
}

struct ContentView: View {
    
    enum QuizMode: String, CaseIterable {
        case chordToTones = "Chord → Tones"
        case guideTones = "3rd & 7th"
        case sequential = "Sequential"
        case tonesToChord = "Tones → Chord"
        case iiVIMode = "ii-V-I"
    }
    
    let notes = ["C","D♭","D","E♭","E","F","G♭","G","A♭","A","B♭","B"]
    //回答UI 異名同音表記対応用
    let noteButtons = ["C","C♯/D♭","D","D♯/E♭","E","F","F♯/G♭","G","G♯/A♭","A","A♯/B♭","B"]
    
    let chordTypes: [ChordType] = [
        ChordType(name: "M7", intervals: [4,7,11]),
        ChordType(name: "7", intervals: [4,7,10]),
        ChordType(name: "m7", intervals: [3,7,10]),
        ChordType(name: "ø", intervals: [3,6,10]),
        ChordType(name: "dim7", intervals: [3,6,9])
    ]
    
    let distractorMap: [String: [String]] = [
        "M7": ["7", "m7", "ø"],
        "7": ["M7", "m7", "ø"],
        "m7": ["7", "M7", "ø"],
        "ø": ["dim7", "m7", "7"],
        "dim7": ["ø", "m7", "7"]
    ]
    
    //回答時に異名同音を同じものとして扱うため
    let noteToSemitone: [String:Int] = [
    "C":0, "B♯":0, "D♭♭":0,
    "C♯":1, "D♭":1, "B♯♯":1,
    "D":2, "E♭♭":2, "C♯♯":2,
    "D♯":3, "E♭":3, "F♭♭":3,
    "E":4, "F♭":4, "D♯♯":4,
    "F":5, "E♯":5, "G♭♭":5,
    "F♯":6, "G♭":6, "E♯♯":6,
    "G":7, "A♭♭":7, "F♯♯":7,
    "G♯":8, "A♭":8,
    "A":9, "B♭♭":9, "G♯♯":9,
    "A♯":10, "B♭":10, "C♭♭":10,
    "B":11, "C♭":11, "A♯♯":11
    ]
    
    
    @State private var gameStarted = false
    //現在のモード
    @State private var mode: QuizMode = .tonesToChord
    //
    @State private var showingAnswer = false
    //コードトーン（表示用）
    @State private var chordTones: [String] = []
    @State private var currentChord: String = "ChordTones"
    //コード進行（表示用。ii-V-Iモード限定）
    @State private var currentProgression: IIVIProgression? = nil
    //正解の中身(tones, chord)
    @State private var fullTones: [(note: String, role: ToneRole)] = []
    @State private var currentQuizChord: Chord? = nil
    //回答順シャッフル（デフォルトはオフ）
    @State private var shuffleEnabled = false
    //プレイヤーの回答
    @State private var selectedNotes: [String] = []
    @State private var selectedChord: String? = nil //tonesToChordモード専用
    //tonesToChordモード用
    @State private var currentRoot: String = ""
    @State private var currentChordType: String = ""
    @State private var currentChordOptions: [Chord] = []
    @State private var promptTones: [String] = [] //問題文表示用
    @State private var showRootInPrompt = true //問題文ルート表示ON/OFF
    @State private var showFifthInPrompt = true //問題文5th表示ON/OFF
    //正解判定をしたかどうか
    @State private var answerChecked = false
    //guideTonesモード 回答ステップ
    //@State private var guideStep = 0
    //sequentialモード 回答させる順番・ステップ
    @State private var answerOrder: [ToneRole] = []
    @State private var answerStep = 0
    //表示遅延（正解時、不正解時）および遅延中フラグ
    @State private var correctDelay: Double = 1.0
    @State private var wrongDelay: Double = 2.0
    @State private var isProcessing = false
    
    //tonesToChordモード ヒント・正答表示制御
    enum RevealStep {
        case none
        case hint
        case answer
    }

    @State private var revealStep: RevealStep = .none
    
    
    //正誤判定用：正解ノート
    var correctNotes: [String] {

        guard fullTones.count >= 3 else { return [] }
        
        if answerOrder.isEmpty {
            return fullTones.map { $0.note }
        }

        guard answerStep < answerOrder.count else { return [] }
        let role = answerOrder[answerStep]

        return fullTones
            .filter { $0.role == role }
            .map { $0.note }

    }
    
    
    //正答表示
    var displayedTones: [String] {
        //とりあえず答えの順番は入れ替えないものとする
        //shuffleEnabled ? chordTones.shuffled() : chordTones
        return chordTones
    }
    
    //回答同時選択数（ボタンを押した状態にできる最大数）
    var maxSelectableCount: Int {
        switch mode {

        case .chordToTones:
            return correctNotes.count   // 7thなら4つ（将来テンションにも対応）

        case .guideTones:
            return 1   // 常に1音ずつ
            
        case .sequential:
            return 1
            
        case .iiVIMode:
            return 1

        case .tonesToChord:
            return 1
            
        }
    }
    
    //出題条件
    var availableChordTypes: [ChordType] {
        if mode == .tonesToChord && !showFifthInPrompt {
            return chordTypes.filter { $0.name != "ø" }
        }

        return chordTypes
    }
    
    //答えさせる(target)音
    var targetRoles: [ToneRole] {
        switch mode {
        case .chordToTones:
            return fullTones.map { $0.role }
            
        case .guideTones:
            return answerOrder
            
        case .sequential:
            return answerOrder
            
        case .iiVIMode:
            return answerOrder
            
        case .tonesToChord:
            return []
        }
    }
    
    
    var visiblePromptTones: [String] {
        if mode != .tonesToChord {
            return []
        }

        return promptTones.filter { tone in
            if !showRootInPrompt, role(for: tone) == .root {
                return false
            }
            if !showFifthInPrompt, role(for: tone) == .fifth {
                return false
            }
            
            return true
        }
    }
    
    
    var isInputDisabled: Bool {
        answerChecked || showingAnswer || isProcessing
    }
    
    var isShuffleAvailable: Bool {
        mode == .guideTones || mode == .sequential || mode == .iiVIMode
    }
    
    var isCheckDisabled: Bool {
        showingAnswer || answerChecked
    }
    
    var isPromptOptionDisabled: Bool {
        mode != .tonesToChord || isProcessing || revealStep != .none || showingAnswer
    }
        
    
    var showButtonLabel: String {
        if mode == .tonesToChord && !showRootInPrompt {
            switch revealStep {
            case .none:
                return "Hint"
            case .hint:
                return "Show"
            case .answer:
                return "Next"
            }
        }

        return showingAnswer ? "Next" : "Show"
    }
    
    //画面描画
    var body: some View {
        
        if !gameStarted {
            
            VStack(spacing: 30) {
                
                Spacer()
                
                Text("Chord Tone Trainer")
                    .font(.largeTitle)
                    .bold()
                
                Button("Start") {
                    gameStarted = true
                    generateChord()
                }
                .font(.title2)
                .padding()
                .frame(maxWidth: 200)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            
        } else {
            
            VStack {
                VStack {
                    
                    // HEADER
                    HStack(spacing: 8) {
                        Text("Mode : ")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(mode.rawValue)
                            .font(.headline)
                            .bold()
                        
                    }
                    
                    .padding(.horizontal)

                    Spacer()

                    // MAIN
                    VStack(spacing: 20) {

                        //問題文
                        if mode == .iiVIMode, let p = currentProgression {
                            HStack(spacing: 6) {
                                Text(p.ii)
                                Text("→")
                                Text(p.v)
                                Text("→")
                                Text(p.i)
                                    .padding(6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .font(.largeTitle)

                        } else {
                            if mode == .tonesToChord {
                                Text(visiblePromptTones.joined(separator: ", ") + " → ?")
                                    .font(.largeTitle)
                                
                                if revealStep == .hint {
                                    Text("Hint... Root = \(currentRoot)")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(currentChord)
                                    .font(.largeTitle)
                            }
                                

                        }
                        
                        //どれを答えるかの表示
                        if answerStep < answerOrder.count {
                            Text("\(roleLabel(answerOrder[answerStep])) ?")
                                .font(.title3)

                        } else if mode == .chordToTones {
                            let rolesText = targetRoles
                                .map { roleLabel($0) }
                                .joined(separator: ", ")

                            Text("\(rolesText)?")
                                .font(.title3)
                        }
                        
                        //正答部分の枠
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]
                        
                        //Spacer()
                        
                        //正答部分の中身
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(displayedTones, id: \.self) { tone in
                                VStack(spacing: 4) {
                                    Text(displayName(for: tone))
                                        .font(.title2)
                                if showingAnswer, let role = role(for: tone) {
                                    Text(role.rawValue)
                                        .font(.caption)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(
                                    role(for: tone)?.color ?? Color.gray.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .opacity(showingAnswer ? 1 : 0)
                            }
                        }.padding()
                    }
                }
                
                
                
                //回答用ボタンUI
                //コード選択UI
                if mode == .tonesToChord {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(currentChordOptions, id: \.self) { chord in
                            let chordLabel = chordName(for: chord)
                            
                            Button {
                                if selectedChord == chordLabel {
                                    selectedChord = nil
                                } else {
                                    selectedChord = chordLabel
                                }
                                
                            } label: {
                                let style = palette(for: chordLabel)
                                
                                Text(chordLabel)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(style.background)
                                    .foregroundColor(style.foreground)
                                    .cornerRadius(8)
                                    .opacity(isInputDisabled ? 0.8 : 1.0)
                            }
                            .disabled(isInputDisabled)
                        }
                    }
                } else {
                //音選択UI
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        
                        ForEach(noteButtons, id: \.self) { note in
                            Button(action: {
                                toggleSelection(note)
                                
                            }) {
                                let style = palette(for: note)
                                
                                Text(note)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(style.background)
                                    .foregroundColor(style.foreground)
                                    .cornerRadius(8)
                                    .opacity(isInputDisabled ? 0.8 : 1.0)
                            }
                            .disabled(isInputDisabled)
                        }
                    }.padding()
                }
                
                
                

                HStack {
                    
                    // CONTROLS
                    Button(action: {
                        if mode == .tonesToChord && !showRootInPrompt {
                            switch revealStep {
                            case .none:
                                revealStep = .hint
                            case .hint:
                                revealStep = .answer
                                showingAnswer = true
                            case .answer:
                                selectedChord = nil
                                generateChord()
                            }
                        } else {
                            if showingAnswer {
                                generateChord()
                            } else {
                                showingAnswer = true
                            }
                        }
                    }) {
                        Text(showButtonLabel)
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: 100)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.5 : 1.0)
                    
                    //回答チェック
                    Button(action: {
                        let isCorrect = checkAnswer()
                        
                        answerChecked = true
                        
                        updateShowingAnswer(isCorrect: isCorrect)
                        
                        proceedAfterAnswer(isCorrect: isCorrect)

                    }) {
                        Text("Check")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: 100)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isCheckDisabled)
                    .opacity(isCheckDisabled ? 0.5 : 1.0)
                }
                
                //各種切り替えトグル
                VStack {
                    Spacer()
                    
                    Toggle("Shuffle Answer Order", isOn: $shuffleEnabled)
                        .disabled(!isShuffleAvailable)
                        .opacity(isShuffleAvailable ? 1.0 : 0.3)
                    Toggle("Show Root in Prompt", isOn: $showRootInPrompt)
                        .disabled(isPromptOptionDisabled)
                        .opacity(!isPromptOptionDisabled ? 1.0 : 0.3)
                    Toggle("Show 5th in Prompt", isOn: $showFifthInPrompt)
                        .disabled(isPromptOptionDisabled)
                        .opacity(!isPromptOptionDisabled ? 1.0 : 0.3)

                }
                .padding(.horizontal, 40)
                
                .padding(.bottom, 20)
                
                //モード切り替え
                Button("Change Mode"){
                    switch mode {
                    case .chordToTones:
                        mode = .sequential
                    case .sequential:
                        mode = .guideTones
                    case .guideTones:
                        mode = .tonesToChord
                    case .tonesToChord:
                        mode = .iiVIMode
                    case .iiVIMode:
                        mode = .chordToTones
                    }
                    
                    if !isShuffleAvailable {
                        shuffleEnabled = false
                    }
                    
                    if mode == .tonesToChord {
                        selectedNotes.removeAll()
                    } else {
                        selectedChord = nil
                    }
                    
                    generateChord()
                }
                .padding(.bottom, 40)
                .disabled(isProcessing || showingAnswer)
            }
        }
    }
    
    //問題を作る
    func generateChord() {
        
        let letters = ["C","D","E","F","G","A","B"]
        
        let naturalSemitones: [String:Int] = [
            "C":0, "D":2, "E":4, "F":5,
            "G":7, "A":9, "B":11
        ]
        
        let degreeSteps = [2,4,6]  // 3rd,5th,7th
        
        //本番用
        let rootIndex = Int.random(in: 0..<notes.count)
        //テスト用（ルートC固定）
        //let rootIndex = 0
        
        let chordType = availableChordTypes.randomElement()!
        
        let root = notes[rootIndex]
        var actualRoot = root
        var actualChordType = chordType
        let actualChord = Chord(root: actualRoot, type: actualChordType)
        
        let correctChord: Chord
        if mode == .tonesToChord, !showRootInPrompt, !showFifthInPrompt,
           let sub = tritoneSubstitute(of: actualChord) {
            correctChord = Bool.random() ? actualChord : sub
        } else {
            correctChord = actualChord
        }
        currentQuizChord = correctChord
        
        
        if mode == .iiVIMode {
            let result = generateIIVI()
            
            //上書きしてる
            currentProgression = result
            actualRoot = result.root
            actualChordType = result.chordType
            
        } else {
            currentProgression = nil
        }
        
        let rootLetter = String(actualRoot.prefix(1))
        let rootLetterIndex = letters.firstIndex(of: rootLetter)!
        
        //リセット
        fullTones = []
        answerOrder = []
        answerStep = 0
        
        
        //root追加
        fullTones.append((note: actualRoot, role: .root))
        
        //3rd以降の音と役割表記の追加
        let roles: [ToneRole] = [.third, .fifth, .seventh]
    
        let rootSemitone = noteToSemitone[actualRoot]!
        
        for (i, interval) in actualChordType.intervals.enumerated() {
            
            let realSemitone = (rootSemitone + interval) % 12
            
            let letterIndex = (rootLetterIndex + degreeSteps[i]) % 7
            let baseLetter = letters[letterIndex]
            
            let baseSemitone = naturalSemitones[baseLetter]!

            var diff = realSemitone - baseSemitone
            if diff > 6 { diff -= 12 }
            if diff < -6 { diff += 12 }
            
            var accidental = ""
            if diff == -2 { accidental = "♭♭" }
            else if diff == -1 { accidental = "♭" }
            else if diff == 1 { accidental = "♯" }
            else if diff == 2 { accidental = "♯♯" }
            
            let theoretical = baseLetter + accidental
                
            fullTones.append((note: theoretical, role: roles[i]))
        }
        
        //リセット
        promptTones = []
        
        
        switch mode {
            
        case .chordToTones:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }
            answerOrder = []
            
        case .guideTones:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }
            answerOrder = [.third, .seventh]
            
        case .sequential:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }
            answerOrder = [.third, .fifth, .seventh]
            
        case .tonesToChord:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }  //正答表示用
            promptTones = chordTones.shuffled() //問題文
            
            let preferredNames = distractorMap[correctChord.type.name] ?? []
            // 優先候補
            var preferredChoices = availableChordTypes.filter {
                preferredNames.contains($0.name)
            }

            // 足りない分を補う
            let remainingChoices = availableChordTypes.filter {
                $0.name != correctChord.type.name && !preferredNames.contains($0.name)
            }

            // 最大3つに制限
            preferredChoices.shuffle()
            var selectedWrongTypes = Array(preferredChoices.prefix(3))

            if selectedWrongTypes.count < 3 {
                let needed = 3 - selectedWrongTypes.count
                let supplement = Array(remainingChoices.shuffled().prefix(needed))
                selectedWrongTypes += supplement
            }
            
            
            let distractorRoot: String
            if correctChord.root != actualChord.root {
                distractorRoot = actualChord.root
                //print("sub!")
            } else {
                distractorRoot = correctChord.root
                
            }
            
            //誤答コードを作る
            var wrongChords = selectedWrongTypes.map {
                Chord(root: distractorRoot, type: $0)
            }
            
            /*
            //条件に合致するなら誤答にトライトーン代理を混ぜる
            if !showRootInPrompt && !showFifthInPrompt,
               let sub = tritoneSubstitute(of: correctChord) {
                if !wrongChords.contains(sub) {
                    if !wrongChords.isEmpty {
                        wrongChords[0] = sub
                    } else {
                        wrongChords.append(sub)
                    }
                }
            }
             */
            
            currentChordOptions = ([correctChord] + wrongChords).shuffled()
            
            
        case .iiVIMode:
            chordTones = fullTones.map { $0.note }
            answerOrder = [.third, .seventh]
            
        }
        
        if shuffleEnabled {
            answerOrder.shuffle()
        }
        
        revealStep = .none
        showingAnswer = false
        
        //Checkの後、Nextを押す際に回答をリセット
        selectedNotes = []
        answerChecked = false
        
        currentRoot = actualRoot
        currentChordType = actualChordType.name
        
        //print(currentChord)
    }
    
    
    func tritoneSubstitute(of chord: Chord) -> Chord? {
        guard chord.type.name == "7" else { return nil }
        //print("7th!")

        guard let rootSemitone = noteToSemitone[chord.root] else { return nil }

        let subRootSemitone = (rootSemitone + 6) % 12
        let subRoot = notes[subRootSemitone]

        return Chord(root: subRoot, type: chord.type)
    }
    
    
    func generateIIVI() -> IIVIProgression {
        
        let rootIndex = Int.random(in: 0..<notes.count)
        let root = notes[rootIndex]
        
        let iiIndex = (rootIndex + 2) % 12
        let vIndex = (rootIndex + 7) % 12
        
        let ii = notes[iiIndex] + "m7"
        let v = notes[vIndex] + "7"
        let i = root + "M7"
        
        let major7 = chordTypes.first { $0.name == "M7" }!
        return IIVIProgression(
            ii: ii,
            v: v,
            i: i,
            root: root,
            chordType: major7
        )
    }
    
    
    func chordName(for chord: Chord) -> String {
        chord.root + chord.type.name
    }
    
    //半音変換関数
    func semitone(for note: String) -> Int? {
        let parts = note.split(separator: "/")

        for p in parts {
            if let s = noteToSemitone[String(p)] {
                return s
            }
        }

        return nil
    }
    
    
    //回答用ボタンの選択状態を切り替える
    func toggleSelection(_ note: String) {
        if selectedNotes.contains(note) {
            selectedNotes.removeAll { $0 == note }
        } else {
            if maxSelectableCount == 1 {    //ガイドトーンモードの時
                selectedNotes = [note]   // ← 最後に押したボタンが選択状態になるよう上書き
            } else if selectedNotes.count < maxSelectableCount {
                selectedNotes.append(note)
            }
        }
    }
    
    
    func palette(for value: String) -> ButtonStylePalette {
        let isSelected: Bool
        let isCorrect: Bool
        
        if mode == .tonesToChord {
            guard let currentQuizChord else {
                return ButtonStylePalette(background: .gray.opacity(0.2), foreground: .blue)
            }
            
            isSelected = (selectedChord == value)
            isCorrect = (value == chordName(for: currentQuizChord))
            
        } else {
            
            isSelected = selectedNotes.contains(value)
            // 異名同音(D♯とE♭など)への対応
            let correctSemitones = correctNotes.compactMap { noteToSemitone[$0] }
            let noteSemitone = semitone(for: value)
            isCorrect = noteSemitone.map { correctSemitones.contains($0) } ?? false
        }
        
        if !answerChecked {
            return isSelected
                ? ButtonStylePalette(
                    background: .blue, foreground: .white)
                : ButtonStylePalette(
                    background: .gray.opacity(0.2),foreground: .blue)
        }
        
        if isSelected && isCorrect {
            return ButtonStylePalette(
                background: .green,
                foreground: .white
            )
        }

        if isSelected && !isCorrect {
            return ButtonStylePalette(
                background: .red,
                foreground: .white
            )
        }

        if !isSelected && isCorrect {
            return ButtonStylePalette(
                background: .green.opacity(0.5),
                foreground: .gray
            )
        }
        
        return ButtonStylePalette(
            background: .gray.opacity(0.2),
            foreground: .blue
        )
        
    }
    
    
    //音から役割を取り出す
    func role(for note: String) -> ToneRole? {
        return fullTones.first { $0.note == note }?.role
    }
    
    //役割から音を取り出す
    func note(for role: ToneRole) -> String? {
        return fullTones.first { $0.role == role }?.note
    }
    
    //問題文表示用ラベル
    func roleLabel(_ role: ToneRole) -> String {
        switch role {
        case .root: return "Root"
        case .third: return "3rd"
        case .fifth: return "5th"
        case .seventh: return "7th"
        //case .ninth: return "9th"
        //case .eleventh: return "11th"
        //case .thirteenth: return "13th"
        }
    }
    
    //答え表示の実音＋理論上音名の併記
    func displayName(for note: String) -> String {
        // 「C♯/D♭」みたいなケースはそのまま
        if note.contains("/") {
            return note
        }

        // 半音に変換できるか
        guard let semitone = noteToSemitone[note] else {
            return note
        }

        // 鍵盤上の代表音（notes配列から）
        let realNote = notes[semitone]

        // 理論名と一致してればそのまま
        if realNote == note {
            return note
        }

        // 違えば併記
        return "\(realNote)（\(note)）"
    }
    
    //正誤判定
    func checkAnswer() -> Bool {
        if mode == .tonesToChord {
            guard let currentQuizChord else { return false }
            return selectedChord == chordName(for: currentQuizChord)
        }
        
        let selectedSemitones =
            selectedNotes.compactMap { semitone(for: $0) }
        let correctSemitones =
            correctNotes.compactMap { noteToSemitone[$0] }
        return selectedSemitones.sorted() == correctSemitones.sorted()
    }
    
    
    func updateShowingAnswer(isCorrect: Bool) {
        if !isCorrect && shouldShowAnswerOnWrong() {
            showingAnswer = true
        }
    }
    
    //小問を全て答えるまで正答を表示しない
    func shouldShowAnswerOnWrong() -> Bool {
        if answerStep < answerOrder.count {
            return answerStep == answerOrder.count - 1
        }

        return true
    }
    
    
    func proceedAfterAnswer(isCorrect: Bool) {
        let delay = isCorrect ? correctDelay : wrongDelay
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isProcessing = false
            if answerStep < answerOrder.count - 1 {
                answerStep += 1
                selectedNotes = []
                answerChecked = false
            } else {
                if mode == .tonesToChord {
                    selectedChord = nil
                }
                generateChord()
            }
        }
    }
    
}



#Preview {
    ContentView()
}
