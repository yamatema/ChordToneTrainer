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

//tonesToChordモード ヒント・正答表示制御
enum RevealStep {
    case none
    case hint
    case answer
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
        case sequential = "Sequential"
        case tonesToChord = "Tones → Chord"
        case iiVIMode = "ii-V-I"
    }
    
    enum SequentialPreset: String, CaseIterable {
        case chordTones = "Full Tones"
        case guideTones = "Guide Tones"
    }
    
    enum PromptVisibility: String, CaseIterable {
        case full = "Full Tones"
        case guideTones = "Guide Tones"
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
    @State private var mode: QuizMode = .tonesToChord
    @State private var sequentialPreset: SequentialPreset = .chordTones
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

    @State private var currentChordOptions: [Chord] = []
    @State private var promptTones: [String] = [] //問題文表示用
    @State private var promptVisibility: PromptVisibility = .full

    @State private var revealStep: RevealStep = .none //ヒント→回答ステップ
    @State private var hintTone: (note: String, role: ToneRole)? = nil
    //正解判定をしたかどうか
    @State private var answerChecked = false
    //sequentialモード 回答させる順番・ステップ
    @State private var answerOrder: [ToneRole] = []
    @State private var answerStep = 0
    //表示遅延（正解時、不正解時）および遅延中フラグ
    @State private var correctDelay: Double = 2.0
    @State private var wrongDelay: Double = 2.0
    @State private var isProcessing = false
    
    //テストプレイ用
    @State private var isTestControlsExpanded = false
    @State private var forceRootCForTest = false
    @State private var forceDominant7ForTest = false
    
    var modeDisplayName: String {
        if mode == .sequential {
            return sequentialPreset.rawValue
        }

        return mode.rawValue
    }
    
    
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
        case .sequential:
            return 1
        case .iiVIMode:
            return 1
        case .tonesToChord:
            return 1
        }
    }

    
    //答えさせる(target)音
    var targetRoles: [ToneRole] {
        switch mode {
        case .chordToTones:
            return fullTones.map { $0.role }
        case .sequential:
            return answerOrder
        case .iiVIMode:
            return answerOrder
        case .tonesToChord:
            return []
        }
    }
    
    var showRootInPrompt: Bool {
        promptVisibility == .full
    }

    var showFifthInPrompt: Bool {
        promptVisibility == .full
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
    
    
    var hintText: String {
        if mode == .tonesToChord {
            if !showRootInPrompt && !showFifthInPrompt,
               let hintTone {
                return "Hint: \(hintTone.note) is \(roleLabel(hintTone.role))."
            }
            return "Hint: Focus the guide tones."
        }
        return "Hint UNAVAILABLE"
    }
    
    
    var isInputDisabled: Bool {
        answerChecked || showingAnswer || isProcessing
    }
    
    var isShuffleAvailable: Bool {
        mode == .sequential || mode == .iiVIMode
    }
    
    var isCheckDisabled: Bool {
        showingAnswer || answerChecked
    }
    
    var isSequentialPresetDisabled: Bool {
        mode != .sequential || isProcessing || showingAnswer || answerChecked
    }
    
    var isPromptOptionDisabled: Bool {
        mode != .tonesToChord || isProcessing || revealStep != .none || showingAnswer
    }
    
    var shouldShowTheoryFeedback: Bool {
        mode == .tonesToChord
        && (showingAnswer || answerChecked || revealStep == .answer)
    }
    
    var otherPossibleChordLabel: String? {
        guard shouldShowTheoryFeedback,
              let currentQuizChord else { return nil }

        let visibleEquivalents = equivalentChords(
            for: currentQuizChord,
            candidates: allCandidateChords()
        )
        
        let dimEquivalents = currentQuizChord.type.name == "dim7"
            ? diminishedEquivalentChords(for: currentQuizChord)
            : []

        let others = Array(Set(visibleEquivalents + dimEquivalents))
            .filter { $0 != currentQuizChord }
            .map { chordName(for: $0) }
            .sorted()

        guard !others.isEmpty else { return nil }

        return "Also possible: \n" + others.joined(separator: ", ")
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
                    ModeHeaderView(modeName: modeDisplayName)
                    
                    .padding(.horizontal)

                    //Spacer()

                    // MAIN
                    VStack{
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
                                
                                if revealStep == .hint && !answerChecked {
                                    Text(hintText)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(currentChord)
                                    .font(.largeTitle)
                            }
                        }
                        
                        if let label = otherPossibleChordLabel {
                            Text(label)
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        
                        //どれを答えるかの表示
                        if answerStep < answerOrder.count {
                            Text("\(roleLabel(answerOrder[answerStep])) ?")
                                .font(.title2)

                        } else if mode == .chordToTones {
                            let rolesText = targetRoles
                                .map { roleLabel($0) }
                                .joined(separator: ", ")

                            Text("\(rolesText)?")
                                .font(.title2)
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
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
                                
                                AnswerButtonLabel(
                                    title: chordLabel,
                                    style: style,
                                    isDisabled: isInputDisabled
                                )
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
                                
                                AnswerButtonLabel(
                                    title: note,
                                    style: style,
                                    isDisabled: isInputDisabled
                                )
                            }
                            .disabled(isInputDisabled)
                        }
                    }.padding()
                }
                
                
                

                ControlButtonsView(
                    showButtonLabel: showButtonLabel,
                    isProcessing: isProcessing,
                    isCheckDisabled: isCheckDisabled,
                    onShowTapped: {
                        if mode == .tonesToChord && promptVisibility == .guideTones {
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
                    },
                    onCheckTapped: {
                        let isCorrect = checkAnswer()

                        answerChecked = true

                        updateShowingAnswer(isCorrect: isCorrect)

                        proceedAfterAnswer(isCorrect: isCorrect)
                    }
                )
                
                //各種切り替えpicker/toggle
                VStack {
                    Spacer()
                    
                    if mode == .sequential {
                        Picker("Sequential Preset", selection: $sequentialPreset) {
                            ForEach(SequentialPreset.allCases, id: \.self) {
                                preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isSequentialPresetDisabled)
                        .opacity(!isSequentialPresetDisabled ? 1.0 : 0.3)
                        .onChange(of: sequentialPreset) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            guard mode == .sequential else { return }
                            guard !isSequentialPresetDisabled else { return }

                            generateChord()
                        }
                        
                        Toggle("Shuffle Answer Order", isOn: $shuffleEnabled)
                            .disabled(!isShuffleAvailable)
                            .opacity(isShuffleAvailable ? 1.0 : 0.3)
                    }
                    
                    if mode == .tonesToChord {
                        Picker("Prompt Visibility", selection: $promptVisibility) {
                            ForEach(PromptVisibility.allCases, id: \.self) { visibility in
                                Text(visibility.rawValue).tag(visibility)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isPromptOptionDisabled)
                        .opacity(!isPromptOptionDisabled ? 1.0 : 0.3)
                        .onChange(of: promptVisibility) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            guard mode == .tonesToChord else { return }
                            guard !isPromptOptionDisabled else { return }

                            generateChord()
                        }

                        
                        TestControlsView(
                            isExpanded: $isTestControlsExpanded,
                            forceRootCForTest: $forceRootCForTest,
                            forceDominant7ForTest: $forceDominant7ForTest
                        )
                        
                    }
                    
                }
                .padding(.horizontal, 40)
                
                .padding(.bottom, 20)
                
                //モード切り替え
                Button("Change Mode"){
                    switch mode {
                    case .chordToTones:
                        mode = .sequential
                    case .sequential:
                        mode = .tonesToChord
                    case .tonesToChord:
                        mode = .iiVIMode
                    case .iiVIMode:
                        mode = .chordToTones
                    }
                    
                    if !isShuffleAvailable {
                        shuffleEnabled = false
                    }
                    
                    selectedNotes.removeAll()
                    selectedChord = nil
                    
                    generateChord()
                    
                }
                .padding(.bottom, 40)
                .disabled(isProcessing || showingAnswer)
            }
        }
    }
    
    //問題を作る
    func generateChord() {
        let rootIndex = forceRootCForTest
            ? 0
            : Int.random(in: 0..<notes.count)
        let chordType = forceDominant7ForTest
            ? chordTypes.first { $0.name == "7"}!
            : chordTypes.randomElement()!
        
        let root = notes[rootIndex]
        var actualRoot = root
        var actualChordType = chordType
        
        if mode == .iiVIMode {
            let result = generateIIVI()
            //上書きしてる
            currentProgression = result
            actualRoot = result.root
            actualChordType = result.chordType
        } else {
            currentProgression = nil
        }
        
        let actualChord = Chord(root: actualRoot, type: actualChordType)
        let correctChord = actualChord
        
        //let candidates = candidateChords(for: actualChord)
        //let equivalents = equivalentChords(for: actualChord, candidates: candidates)
        
        currentQuizChord = correctChord

        
        //リセット
        fullTones = []
        answerOrder = []
        answerStep = 0
        promptTones = []
        hintTone = nil
        
        fullTones = buildTones(for: actualChord)
        
        switch mode {
            
        case .chordToTones:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }
            answerOrder = []
            
        case .sequential:
            currentChord = actualRoot + actualChordType.name
            chordTones = fullTones.map { $0.note }
            
            switch sequentialPreset {
            case .chordTones:
                answerOrder = [.third, .fifth, .seventh]
            case .guideTones:
                answerOrder = [.third, .seventh]
            }
            
        case .tonesToChord:
            chordTones = buildTones(for: correctChord).map { $0.note }
            //正答表示用
            promptTones = chordTones.shuffled() //問題文
            
            currentChordOptions = makeChordOptions(
                correctChord: correctChord,
                actualChord: actualChord
            )
            
            let quizTones = buildTones(for: correctChord)

            let visibleGuideTones = quizTones.filter { tone in
                if !showRootInPrompt && tone.role == .root {
                    return false
                }

                if !showFifthInPrompt && tone.role == .fifth {
                    return false
                }

                return tone.role == .third || tone.role == .seventh
            }

            hintTone = visibleGuideTones.randomElement()
            
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
        
    }
    
    
    func buildTones(for chord: Chord) -> [(note: String, role: ToneRole)] {
        let letters = ["C","D","E","F","G","A","B"]
        let naturalSemitones: [String:Int] = [
            "C":0, "D":2, "E":4, "F":5,
            "G":7, "A":9, "B":11
        ]
        let degreeSteps = [2,4,6]
        let roles: [ToneRole] = [.third, .fifth, .seventh]

        let root = chord.root
        let rootLetter = String(root.prefix(1))
        let rootLetterIndex = letters.firstIndex(of: rootLetter)!
        let rootSemitone = noteToSemitone[root]!

        var tones: [(note: String, role: ToneRole)] = []
        tones.append((note: root, role: .root))

        for (i, interval) in chord.type.intervals.enumerated() {
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

            tones.append((note: baseLetter + accidental, role: roles[i]))
        }

        return tones
    }
    
    
    func makeChordOptions(correctChord: Chord, actualChord: Chord) -> [Chord] {
        let preferredNames = distractorMap[correctChord.type.name] ?? []

        var preferredChoices = chordTypes.filter {
            preferredNames.contains($0.name)
        }

        let remainingChoices = chordTypes.filter {
            $0.name != correctChord.type.name && !preferredNames.contains($0.name)
        }

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
        } else {
            distractorRoot = correctChord.root
        }

        let wrongChords = selectedWrongTypes.map {
            Chord(root: distractorRoot, type: $0)
        }
        
        let correctSignature = visibleSignature(for: correctChord)
        var filteredWrongChords = wrongChords.filter { chord in
            chord != correctChord
            && visibleSignature(for: chord) != correctSignature
        }
        
        
        if filteredWrongChords.count < 3 {
            let needed = 3 - filteredWrongChords.count
            let supplementCandidates = chordTypes
                .map { Chord(root: distractorRoot, type: $0) }
                .filter { chord in
                    chord != correctChord
                    && visibleSignature(for: chord) != correctSignature
                    && !filteredWrongChords.contains(chord)
                }
                .shuffled()
            filteredWrongChords += Array(supplementCandidates.prefix(needed))
        }
        
        
        if !showRootInPrompt {
            let rootOffsets = [0, 7, 5] // 正解root, 5度上, 4度上
            let optionsPerRoot = 4

            var options: [Chord] = []

            for offset in rootOffsets {
                guard let root = rootByOffset(from: correctChord.root, offset: offset) else {
                    continue
                }

                // このrootで使える候補を作る
                let candidates = chordTypes
                    .map { Chord(root: root, type: $0) }
                    .filter { chord in
                        chord == correctChord ||
                        (
                            chord != correctChord &&
                            visibleSignature(for: chord) != correctSignature &&
                            !options.contains(chord)
                        )
                    }

                if root == correctChord.root {
                    options.append(correctChord)

                    let wrongForSameRoot = candidates
                        .filter { $0 != correctChord }
                        .shuffled()
                        .prefix(optionsPerRoot - 1)

                    options += Array(wrongForSameRoot)
                } else {
                    let wrongForOtherRoot = candidates
                        .filter { $0 != correctChord }
                        .shuffled()
                        .prefix(optionsPerRoot)

                    options += Array(wrongForOtherRoot)
                }
            }

            return Array(options.prefix(rootOffsets.count * optionsPerRoot)).shuffled()
        } else {
            return ([correctChord] + filteredWrongChords.prefix(3)).shuffled()
        }
    }
    
    
    func tritoneSubstitute(of chord: Chord) -> Chord? {
        guard chord.type.name == "7" else { return nil }

        guard let rootSemitone = noteToSemitone[chord.root] else { return nil }

        let subRootSemitone = (rootSemitone + 6) % 12
        let subRoot = notes[subRootSemitone]

        return Chord(root: subRoot, type: chord.type)
    }
    
    
    func visibleSignature(for chord: Chord) -> [Int] {
        let tones = buildTones(for: chord)

        let visible = tones.filter { tone in
            if !showRootInPrompt && tone.role == .root { return false }
            if !showFifthInPrompt && tone.role == .fifth { return false }
            return true
        }

        return visible.compactMap { noteToSemitone[$0.note] }
            .sorted()
    }
    
    
    func allCandidateChords() -> [Chord] {
        notes.flatMap { root in
            chordTypes.map { type in
                Chord(root: root, type: type)
            }
        }
    }
    
    func rootByOffset(from root: String, offset: Int) -> String? {
        guard let semitone = noteToSemitone[root] else { return nil }
        return notes[(semitone + offset) % 12]
    }
    
    
    func equivalentChords(for chord: Chord, candidates: [Chord]) -> [Chord] {
        let targetSignature = visibleSignature(for: chord)

        return candidates.filter {
            visibleSignature(for: $0) == targetSignature
        }
    }
    

    // プレイヤーから見た状態での「類似度」スコア　高いほど似ている
    func similarityScore(_ chord: Chord, to targetSignature: [Int]) -> Int {
        let sig = visibleSignature(for: chord)
        return sig.filter { targetSignature.contains($0) }.count
    }
    
    
    func diminishedEquivalentChords(for chord: Chord) -> [Chord] {
        guard chord.type.name == "dim7" else { return [] }

        return diminishedEquivalentRoots(for: chord.root).map {
            Chord(root: $0, type: chord.type)
        }
    }
    func diminishedEquivalentRoots(for root: String) -> [String] {
        [0, 3, 6, 9].compactMap {
            rootByOffset(from: root, offset: $0)
        }
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
        let shouldReveal = answerChecked || showingAnswer
        
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
        
        if !shouldReveal {
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
    

    func role(for note: String) -> ToneRole? {
        if mode == .tonesToChord,
           let currentQuizChord {
            return buildTones(for: currentQuizChord)
                .first { $0.note == note }?
                .role
        }
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
            
            if mode == .tonesToChord {
                selectedChord = nil
                generateChord()
                return
            }
            
            if answerStep < answerOrder.count - 1 {
                answerStep += 1
                selectedNotes = []
                answerChecked = false
            } else {
                generateChord()
            }
        }
    }
    
}


struct TestControlsView: View {
    @Binding var isExpanded: Bool
    @Binding var forceRootCForTest: Bool
    @Binding var forceDominant7ForTest: Bool

    var body: some View {
        DisclosureGroup("Test Controls", isExpanded: $isExpanded) {
            VStack(alignment: .leading) {
                Toggle("↳ Force Root C", isOn: $forceRootCForTest)
                Toggle("↳ Force 7 Chord", isOn: $forceDominant7ForTest)
            }
            .padding(.leading, 24)
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            if !newValue {
                forceRootCForTest = false
                forceDominant7ForTest = false
            }
        }
    }
}


struct ModeHeaderView: View {
    let modeName: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Mode : ")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(modeName)
                .font(.headline)
                .bold()
        }
        .padding(.horizontal)
    }
}


struct AnswerButtonLabel: View {
    let title: String
    let style: ButtonStylePalette
    let isDisabled: Bool

    var body: some View {
        Text(title)
            .font(.title3)
            .frame(maxWidth: .infinity)
            .padding()
            .background(style.background)
            .foregroundColor(style.foreground)
            .cornerRadius(8)
            .opacity(isDisabled ? 0.8 : 1.0)
    }
}


struct ControlButtonsView: View {
    let showButtonLabel: String
    let isProcessing: Bool
    let isCheckDisabled: Bool
    let onShowTapped: () -> Void
    let onCheckTapped: () -> Void

    var body: some View {
        HStack {
            Button(action: {
                onShowTapped()
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

            Button(action: {
                onCheckTapped()
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
    }
}


#Preview {
    ContentView()
}
