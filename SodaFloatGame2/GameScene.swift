import SpriteKit
import GameplayKit

// 衝突判定のためにカテゴリビットマスクを定義
struct PhysicsCategory {
    static let none: UInt32      = 0
    static let all: UInt32       = UInt32.max
    static let cherry: UInt32    = 0b1       // 1
    static let soda: UInt32      = 0b10      // 2
    static let ground: UInt32    = 0b100     // 4 (画面外の地面)
}

struct UIConstants {
    struct Fonts {
        static let regular = "AvenirNext-Regular"
        static let bold = "AvenirNext-Bold"
    }
    struct FontSizes {
        static let title: CGFloat = 40
        static let score: CGFloat = 30
        static let button: CGFloat = 30
        static let body: CGFloat = 25
        static let small: CGFloat = 20
    }
    struct Colors {
        static let darkGray = UIColor.darkGray
        static let lightGray = UIColor.lightGray
        static let gameOverRed = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
    }
    struct ZPositions {
        static let background: CGFloat = -1
        static let soda: CGFloat = 5
        static let cherry: CGFloat = 6
        static let ui: CGFloat = 10
        static let panel: CGFloat = 100
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Game Properties
    
    private var cherryNode: SKSpriteNode!
    private var sodaNode: SKSpriteNode!
    private var isGoodCherry: Bool = true // 現在のチェリーが良いチェリーか
    
    private var gameStarted: Bool = false // ゲームが開始しているか
    private var gameEnded: Bool = false   // ゲームが終了しているか
    
    private var isHelpPanelVisible: Bool = false
    private var helpPanelNode: SKNode!
    
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    private var highScore: Int = 0
    private var highScoreLabel: SKLabelNode!
    private var helpButtonNode: SKNode!
    private var safeAreaInsets: UIEdgeInsets = .zero
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        safeAreaInsets = view.safeAreaInsets
        
        backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        
        // 物理エンジンの設定
        physicsWorld.gravity = CGVector(dx: 0, dy: -2.0) // 重力を設定 (強さ調整可能)
        physicsWorld.contactDelegate = self // 衝突検知のデリゲートを設定
        
        setupGround() // 地面ノードの追加
        setupSoda()
        setupScoreLabel()
        setupHighScoreLabel()
        loadHighScore()
        setupHelpButton()
        
        // 最初はcherryを表示せず、ゲーム開始を待つ
        // cherryを生成し、落下させるのはゲーム開始（最初のタップ）後
        // createCherry() // この時点ではまだ作らない
        
        // ゲーム開始を促すラベル
        let startLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        startLabel.text = "Tap to Start!"
        startLabel.fontColor = UIConstants.Colors.darkGray
        startLabel.position = CGPoint(x: frame.midX, y: frame.midY + 200)
        startLabel.name = "startLabel"
        addChild(startLabel)
    }
    
    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = UIConstants.FontSizes.score
        scoreLabel.fontColor = UIConstants.Colors.darkGray
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 300 )
        scoreLabel.zPosition = UIConstants.ZPositions.ui
        addChild(scoreLabel)
    }
    
    private func setupHighScoreLabel() {
        highScoreLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        highScoreLabel.text = "High Score: 0"
        highScoreLabel.fontSize = UIConstants.FontSizes.small
        highScoreLabel.fontColor = UIConstants.Colors.lightGray
        highScoreLabel.position = CGPoint(x: frame.midX, y: scoreLabel.position.y - 50)
        highScoreLabel.zPosition = UIConstants.ZPositions.ui
        addChild(highScoreLabel)
    }
    
    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: "highScore")
        highScoreLabel.text = "High Score: \(highScore)"
    }
    
    private func saveHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
            highScoreLabel.text = "High Score: \(highScore)"
        }
    }
    
    private func setupSoda() {
        sodaNode = SKSpriteNode(imageNamed: "sodafloat") // soda.png を使用
        sodaNode.position = CGPoint(x: frame.midX, y: frame.minY + sodaNode.size.height / 2) // 画面下部に配置
        sodaNode.zPosition = UIConstants.ZPositions.soda
        addChild(sodaNode)
        
        sodaNode.physicsBody = SKPhysicsBody(rectangleOf: sodaNode.size) // 四角形で作成
        sodaNode.physicsBody?.isDynamic = false // 動かないようにする
        sodaNode.physicsBody?.categoryBitMask = PhysicsCategory.soda // sodaカテゴリに設定
        sodaNode.physicsBody?.collisionBitMask = PhysicsCategory.none
        sodaNode.physicsBody?.contactTestBitMask = PhysicsCategory.cherry // cherryとの接触を検知する
    }
    
    private func setupGround() {
        let ground = SKSpriteNode(color: .clear, size: CGSize(width: frame.width, height: 10))
        ground.position = CGPoint(x: frame.midX, y: -100) // 画面外の少し下
        ground.name = "ground"
        addChild(ground)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ground.physicsBody?.collisionBitMask = PhysicsCategory.none // 他のオブジェクトとは衝突しない
        ground.physicsBody?.contactTestBitMask = PhysicsCategory.cherry // cherryとの接触を検知
    }
    
    private func createNeuromorphicNode(size: CGSize, cornerRadius: CGFloat) -> SKNode {
        let node = SKNode()
        let base = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        base.fillColor = backgroundColor
        base.strokeColor = .clear
        node.addChild(base)
        
        let darkShadow = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        darkShadow.position = CGPoint(x: 3, y: -3)
        darkShadow.fillColor = UIConstants.Colors.darkGray.withAlphaComponent(0.5)
        darkShadow.strokeColor = .clear
        darkShadow.zPosition = UIConstants.ZPositions.background
        base.addChild(darkShadow)
        
        let lightShadow = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        lightShadow.position = CGPoint(x: -3, y: 3)
        lightShadow.fillColor = UIColor.white.withAlphaComponent(0.9)
        lightShadow.strokeColor = .clear
        lightShadow.zPosition = UIConstants.ZPositions.background
        base.addChild(lightShadow)
        
        return node
    }
    
    private func setupHelpButton() {
        let buttonSize = CGSize(width: 50, height: 50)
        helpButtonNode = createNeuromorphicNode(size: buttonSize, cornerRadius: 25)
        
        let margin: CGFloat = 20
        helpButtonNode.position = CGPoint(x: frame.maxX - safeAreaInsets.right - buttonSize.width - margin - 100,
                                          y: frame.maxY - safeAreaInsets.top - buttonSize.height - margin - 100)
        helpButtonNode.name = "helpButton"
        helpButtonNode.zPosition = UIConstants.ZPositions.ui
        addChild(helpButtonNode)
        
        // Help icon text
        let helpLabel = SKLabelNode(fontNamed: UIConstants.Fonts.bold)
        helpLabel.text = "?"
        helpLabel.fontSize = UIConstants.FontSizes.button
        helpLabel.fontColor = UIConstants.Colors.darkGray
        helpLabel.horizontalAlignmentMode = .center
        helpLabel.verticalAlignmentMode = .center
        helpButtonNode.children.first?.addChild(helpLabel)
        
        setupHelpPanel()
    }
    
    private func setupHelpPanel() {
        let panelSize = CGSize(width: frame.width * 0.75, height: frame.height * 0.6)
        helpPanelNode = createNeuromorphicNode(size: panelSize, cornerRadius: 20)
        helpPanelNode.position = CGPoint(x: frame.midX, y: frame.midY)
        helpPanelNode.zPosition = UIConstants.ZPositions.panel
        helpPanelNode.isHidden = true
        addChild(helpPanelNode)
        
        let panelBase = helpPanelNode.children.first!
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: UIConstants.Fonts.bold)
        titleLabel.text = "How to Play"
        titleLabel.fontSize = UIConstants.FontSizes.score
        titleLabel.fontColor = UIConstants.Colors.darkGray
        titleLabel.position = CGPoint(x: 0, y: panelSize.height / 2 - 50)
        panelBase.addChild(titleLabel)
        
        // Instructions
        let instructions = "Tap to stop the cherry.\n\n- Good cherries on icecream: +1 point\n- Bad cherries on icecream: Game Over\n- Good cherries on the ground: Game Over\n- Bad cherries on the ground: +1 point\n\nTap the screen to close this window."
        let instructionLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        instructionLabel.text = instructions
        instructionLabel.fontSize = UIConstants.FontSizes.body
        instructionLabel.fontColor = UIConstants.Colors.darkGray
        instructionLabel.numberOfLines = 0
        instructionLabel.preferredMaxLayoutWidth = panelSize.width - 40
        instructionLabel.position = CGPoint(x: 0, y: 0)
        panelBase.addChild(instructionLabel)
    }
    
    private func createCherry() {
        // 既存のcherryがあれば削除
        cherryNode?.removeFromParent()
        
        // ランダムに良いチェリーか悪いチェリーかを決定
        isGoodCherry = arc4random_uniform(2) == 0 // 0なら良いチェリー
        let imageName = isGoodCherry ? "cherry" : "badcherry"
        
        cherryNode = SKSpriteNode(imageNamed: imageName)
        cherryNode.size = CGSize(width: 300, height: 300)
        
        // cherryの初期位置（画面上部中央）
        cherryNode.position = CGPoint(x: frame.midX + 100, y: frame.maxY + cherryNode.size.height / 2)
        cherryNode.zPosition = UIConstants.ZPositions.cherry
        cherryNode.name = "cherry" // ノードに名前を付けて識別しやすくする
        addChild(cherryNode)
        
        // cherryの物理ボディを設定
        // 円形で物理ボディを作成 (より自然な当たり判定)
        cherryNode.physicsBody = SKPhysicsBody(circleOfRadius: cherryNode.size.width / 2 * 0.8) // 少し小さくして調整
        cherryNode.physicsBody?.isDynamic = true // 物理演算によって動く
        cherryNode.physicsBody?.affectedByGravity = true // 重力の影響を受ける
        cherryNode.physicsBody?.restitution = 0.3 // 反発係数 (少し跳ねる)
        cherryNode.physicsBody?.allowsRotation = true // 回転を許可
        
        cherryNode.physicsBody?.categoryBitMask = PhysicsCategory.cherry // cherryカテゴリに設定
        cherryNode.physicsBody?.collisionBitMask = PhysicsCategory.none // 他のオブジェクトとは物理的に衝突しない
        cherryNode.physicsBody?.contactTestBitMask = PhysicsCategory.soda | PhysicsCategory.ground // sodaまたは地面との接触を検知する
    }
    
    // MARK: - Game Logic
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isHelpPanelVisible {
            helpPanelNode.isHidden = true
            isHelpPanelVisible = false
            // Unpause the game if it was paused
            physicsWorld.speed = 1.0
            return
        }
        
        var touchedNode = atPoint(location)
        while touchedNode != self {
            if touchedNode.name == "helpButton" {
                helpPanelNode.isHidden = false
                isHelpPanelVisible = true
                // Pause the game
                physicsWorld.speed = 0.0
                return
            }
            guard let parent = touchedNode.parent else { break }
            touchedNode = parent
        }
        
        if gameEnded {
            // ゲームオーバー後のタップでリスタート
            restartGame()
            return
        }
        
        if !gameStarted {
            // 最初のタップでゲーム開始
            gameStarted = true
            childNode(withName: "startLabel")?.removeFromParent()
            createCherry() // 最初のcherryを生成
            return
        }
        
        // cherryが存在しない、またはすでに落ちている最中であれば処理しない
        guard let cherryNode = cherryNode, cherryNode.parent != nil else { return }
        
        // sodaのフレームの上半分を「成功ゾーン」とする
        let sodaSuccessZone = CGRect(x: sodaNode.frame.minX,
                                     y: sodaNode.frame.midY, // sodaの中央から
                                     width: sodaNode.frame.width,
                                     height: sodaNode.frame.height / 7.5)
        
        // タップ時のcherryの現在位置 (プレゼンテーションレイヤー)
        guard let cherryCurrentFrame = cherryNode.physicsBody?.node?.frame else {
            // 物理ボディのノードフレームが取得できない場合は何もしない
            return
        }
        
        // cherryとsodaの「成功ゾーン」が重なっていたらクリア
        if cherryCurrentFrame.intersects(sodaSuccessZone) {
            if isGoodCherry {
                print("クリア！良いチェリーがソータにイン！")
                score += 1
                // 成功したcherryは物理挙動を止めてsodaに乗ったように見せる
                cherryNode.physicsBody?.isDynamic = false
                cherryNode.physicsBody?.affectedByGravity = false
                
                // 少しディレイを置いて次のcherryを生成 (連続タップ防止)
                run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                    self?.createCherry()
                }
            } else {
                print("ゲームオーバー！悪いチェリーがソータにイン！")
                gameOver()
            }
        } else {
            print("ミス！タイミングが合わない、または範囲外！")
            gameOver()
        }
    }
    
    private func gameOver() {
        if gameEnded { return } // すでにゲームオーバーなら何もしない
        gameEnded = true
        print("--- ゲームオーバー ---")
        
        saveHighScore()
        
        // ゲームオーバー時にチェリーを削除せず、落下を続けるようにする
        // cherryNode?.removeFromParent()
        
        // タイマーなどがある場合はここで停止
        // cherryNode?.physicsBody?.isDynamic = false // cherryの動きを止める
        
        let gameOverLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        gameOverLabel.text = "Game Over! Score: \(score) "
        gameOverLabel.fontSize = UIConstants.FontSizes.score
        gameOverLabel.fontColor = UIConstants.Colors.gameOverRed
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY + 250)
        gameOverLabel.name = "gameOverLabel"
        addChild(gameOverLabel)
        
        let restartLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        restartLabel.text = "Tap to Restart"
        restartLabel.fontSize = UIConstants.FontSizes.body
        restartLabel.fontColor = UIConstants.Colors.darkGray
        restartLabel.position = CGPoint(x: frame.midX, y: frame.midY + 200)
        restartLabel.name = "restartLabel"
        addChild(restartLabel)
    }
    
    private func restartGame() {
        // ゲームオーバー関連のノードを削除
        childNode(withName: "gameOverLabel")?.removeFromParent()
        childNode(withName: "restartLabel")?.removeFromParent()
        
        // cherryとsodaをリセット
        cherryNode?.removeFromParent()
        
        score = 0
        gameEnded = false
        gameStarted = false
        
        // 再びスタートを促すラベルを表示
        let startLabel = SKLabelNode(fontNamed: UIConstants.Fonts.regular)
        startLabel.text = "Tap to Start!"
        startLabel.fontSize = UIConstants.FontSizes.title
        startLabel.fontColor = UIConstants.Colors.darkGray
        startLabel.position = CGPoint(x: frame.midX, y: frame.midY + 200)
        startLabel.name = "startLabel"
        addChild(startLabel)
        
        // 物理エンジンの速度をリセット（念のため）
        physicsWorld.speed = 1.0
    }
    
    // MARK: - SKPhysicsContactDelegate (衝突検知)
    
    func didBegin(_ contact: SKPhysicsContact) {
        if gameEnded { return } // ゲームオーバー後は何もしない
        
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == (PhysicsCategory.cherry | PhysicsCategory.ground) {
            let cherryBody = (contact.bodyA.categoryBitMask == PhysicsCategory.cherry) ? contact.bodyA : contact.bodyB
            if let cherryNode = cherryBody.node as? SKSpriteNode {
                if isGoodCherry {
                    print("良いチェリーが地面に到達しました。ゲームオーバー！")
                    gameOver()
                } else {
                    score += 1
                    print("悪いチェリーが地面に到達しました。クリア！")
                    // すぐに削除せず、画面外に落ちてから削除するアクションを実行
                    let fallOffScreenAction = SKAction.sequence([
                        SKAction.wait(forDuration: 1.0), // 画面外に完全に出るまでの時間
                        SKAction.removeFromParent()
                    ])
                    if let cherryNode = cherryBody.node {
                        cherryNode.run(fallOffScreenAction)
                    }
                    // 少しディレイを置いて次のcherryを生成
                    run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                        self?.createCherry()
                    }
                }
            }
        }
    }
}
