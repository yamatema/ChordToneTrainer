//
//  ContentView.swift
//  ChordToneTrainer
//
//  Created by Yamamoto Takuya on 2026/03/14.
//

import SwiftUI

struct ContentView: View {
    
    enum QuizMode: String, CaseIterable {
        case chordToTones = "Chord → Tones"
        case guideTones = "3rd & 7th"
        case tonesToChord = "Tones → Chord"
        case iiVIMode = "ii-V-I"
    }
    
    let notes = ["C","D♭","D","E♭","E","F","G♭","G","A♭","A","B♭","B"]
    //回答UI 異名同音表記対応用
    let noteButtons = ["C","C♯/D♭","D","D♯/E♭","E","F","F♯/G♭","G","G♯/A♭","A","A♯/B♭","B"]
    
    
    let chordTypes: [(name: String, intervals: [Int])] = [
        ("M7", [4,7,11]),
        ("7", [4,7,10]),
        ("m7", [3,7,10]),
        ("ø", [3,6,10]),
        ("dim7", [3,6,9])
    ]
    
    //回答時に異名同音を同じものとして扱うため
    let noteToSemitone: [String:Int] = [
    "C":0, "B♯":0, "D♭♭":0,
    "C♯":1, "D♭":1,
    "D":2, "E♭♭":2,
    "D♯":3, "E♭":3, "F♭♭":3,
    "E":4, "F♭":4,
    "F":5, "E♯":5, "G♭♭":5,
    "F♯":6, "G♭":6,
    "G":7, "A♭♭":7,
    "G♯":8, "A♭":8,
    "A":9, "B♭♭":9,
    "A♯":10, "B♭":10, "C♭♭":10,
    "B":11, "C♭":11
    ]
    
    
    @State private var gameStarted = false
    //現在のモード
    @State private var mode: QuizMode = .chordToTones
    //
    @State private var showingAnswer = false
    //コードトーン（表示用）
    @State private var chordTones: [String] = []
    @State private var currentChord: String = "ChordTones"
    //コードトーン（正解の中身）
    @State private var fullTones: [(note: String, role: String)] = []
    //コードトーンシャッフル（デフォルトはオフ）
    @State private var shuffleEnabled = false
    //プレイヤーの回答
    @State private var selectedNotes: [String] = []
    //正解判定をしたかどうか
    @State private var answerChecked = false
    //ガイドトーンモードの回答ステップ (0なら1段階目:3rd、1なら2段階目:7th)
    @State private var guideStep = 0
    //表示遅延（正解時、不正解時）
    @State private var correctDelay: Double = 1.0
    @State private var wrongDelay: Double = 2.0
    
    
    
    //正誤判定用：正解ノート
    var correctNotes: [String] {

        guard fullTones.count >= 3 else { return [] }

        switch mode {

        case .guideTones:
            if guideStep == 0 {
                return [note(for: "3rd")!] //3rd
            } else {
                return [note(for: "7th")!] //7th
            }

        case .chordToTones:
            return fullTones.map { $0.note }

        default:
            return fullTones.map { $0.note }
        }
    }
    
    
    //表示用のコードトーン（コードトーンシャッフルへの対応）
    var displayedTones: [String] {
        shuffleEnabled ? chordTones.shuffled() : chordTones
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

                        Text(currentChord)
                            .font(.largeTitle)
                        
                        //ガイドトーンモード時の問題文
                        if mode == .guideTones {
                            Text(guideStep == 0 ? "3rd ?" : "7th ?")
                                .font(.title3)
                        }

                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]
                        
                        Spacer()
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(displayedTones, id: \.self) { tone in
                                VStack(spacing: 4) {
                                    Text(tone)
                                        .font(.title2)

                                    if showingAnswer {
                                        Text(role(for: tone) ?? "")
                                            .font(.caption)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(backgroundColor(for: tone))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .opacity(showingAnswer ? 1 : 0)
                            }
                        }
                        .padding()
                    }
                }
                
                
                
                //回答用ボタンUI
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    
                    ForEach(noteButtons, id: \.self) { note in
                        
                        Button(action: {
                            toggleSelection(note)

                        }) {
                            Text(note)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonColor(for: note))
                            .cornerRadius(8)
                            .opacity(answerChecked ? 0.65 : 1.0)
                        }
                        .disabled(answerChecked)
                    }
                }
                .padding()
                
                

                HStack {
                    
                    // CONTROLS
                    Button(action: {
                        if showingAnswer {
                            generateChord()
                        } else {
                            showingAnswer = true
                        }
                    }) {
                        Text(showingAnswer ? "Next" : "Show")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: 100)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    
                    //回答チェック
                    Button(action: {
                        
                        let isCorrect = checkAnswer()
                        
                        //判定表示
                        answerChecked = true
                        
                        if !isCorrect {
                            showingAnswer = true
                        }
                        
                        proceedAfterAnswer(isCorrect: isCorrect)

                    }) {
                        Text("Check")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: 100)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                }
                
                HStack {
                    Spacer()
                    
                    //コードトーンのシャッフル機能をON/OFF
                    Toggle("Chord Tone Shuffle", isOn: $shuffleEnabled)
                        //.labelsHidden()

                }
                .padding(.horizontal, 40)
                
                .padding(.bottom, 20)
                
                //モード切り替え
                Button("Change Mode"){
                    switch mode {
                    case .chordToTones:
                        mode = .guideTones
                    case .guideTones:
                        mode = .tonesToChord
                    case .tonesToChord:
                        mode = .iiVIMode
                    case .iiVIMode:
                        mode = .chordToTones
                    }
                    generateChord()
                }
                .padding(.bottom, 40)
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
        
        let rootIndex = Int.random(in: 0..<notes.count)
        let chordType = chordTypes.randomElement()!
        
        let root = notes[rootIndex]
        let rootLetter = String(root.prefix(1))
        let rootLetterIndex = letters.firstIndex(of: rootLetter)!
        
        //ii-V-Iモード時
        if mode == .iiVIMode {
            let result = generateIIVI()
            
            currentChord = result.0
            chordTones = [result.1]
            
            showingAnswer = false
            return
        }
        
        fullTones = [] //リセット
        
        //root追加
        fullTones.append((note: root, role: "root"))
        
        //役割表記
        let roles = ["3rd", "5th", "7th"]
        
        for (i, interval) in chordType.intervals.enumerated() {
            
            let realIndex = (rootIndex + interval) % 12
            
            let letterIndex = (rootLetterIndex + degreeSteps[i]) % 7
            let baseLetter = letters[letterIndex]
            
            let baseSemitone = naturalSemitones[baseLetter]!
            let realSemitone = realIndex
            
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
        
        switch mode {
            
        case .chordToTones:
            currentChord = root + chordType.name
            chordTones = fullTones.map { $0.note }
            
        case .guideTones:
            currentChord = root + chordType.name
            chordTones = [ note(for: "root")!, note(for: "5th")! ] // root と 5th 表示
            
        case .tonesToChord:
            currentChord = "Which chord?"
            chordTones = fullTones.map { $0.note }
            
        case .iiVIMode:
            break
            
        }
        
        
        showingAnswer = false
        
        //Checkの後、Nextを押す際に回答をリセット
        selectedNotes = []
        answerChecked = false
        guideStep = 0
    }
    
    
    func generateIIVI() -> (String, String) {
        
        let rootIndex = Int.random(in: 0..<notes.count)
        let root = notes[rootIndex]
        
        let iiIndex = (rootIndex + 2) % 12
        let vIndex = (rootIndex + 7) % 12
        
        let ii = notes[iiIndex] + "m7"
        let v = notes[vIndex] + "7"
        let i = root + "M7"
        
        let question = ii + " → " + v + " → ?"
        
        return (question, i)
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
            selectedNotes.append(note)
        }
    }
    
    
    //回答UIのボタン色（選択/非選択、正解/不正解）決定
    func buttonColor(for note: String) -> Color {
        //選択中かどうか
        let isSelected = selectedNotes.contains(note)
        
        //Check前・選択状態によりボタン色を決定
        if !answerChecked {
            if isSelected {
                return .blue.opacity(0.5)
            } else {
                return Color.gray.opacity(0.2)
            }
        }

        //Check後・選択状態によりボタン色を決定
        //異名同音(D♯とE♭など)への対応
        let correctSemitones = correctNotes.compactMap { noteToSemitone[$0] }
        let noteSemitone = semitone(for: note)

        //正解かどうか
        let isCorrect = noteSemitone.map { correctSemitones.contains($0) } ?? false

            
        if isSelected && isCorrect {
            return .green                  //選択していて正解
        }
        
        if isSelected && !isCorrect {
            return .red                    //選択していて不正解
        }

        if !isSelected && isCorrect {
            return .green.opacity(0.3)     //選択していなかった正解
        }
            
        return Color.gray.opacity(0.2)     //それ以外

    }
    

    //音から役割を取り出す関数
    func role(for note: String) -> String? {
        return fullTones.first { $0.note == note }?.role
    }
    
    //役割から音を取り出す関数
    func note(for role: String) -> String? {
        return fullTones.first { $0.role == role }?.note
    }
    
    func checkAnswer() -> Bool {
        let selectedSemitones =
            selectedNotes.compactMap { semitone(for: $0) }
        let correctSemitones =
            correctNotes.compactMap { noteToSemitone[$0] }
        return selectedSemitones.sorted() == correctSemitones.sorted()
    }
    
    
    func proceedAfterAnswer(isCorrect: Bool) {
        let delay = isCorrect ? correctDelay : wrongDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if mode == .guideTones {
                if guideStep == 0 {
                    guideStep = 1   //3rdを答えたら7thへ
                    selectedNotes = []
                    answerChecked = false
                } else {
                    generateChord() //7thを答えたら次の問題へ
                }
            } else {
                //ガイドトーンモードでない時はすぐ次の問題へ
                generateChord()
            }
        }
    }
    
    //
    func backgroundColor(for tone: String) -> Color {
        switch role(for: tone) {
        case "root": return .gray
        case "3rd": return .blue
        case "5th": return .gray
        case "7th": return .red
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
