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

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Game Properties
    
    private var cherryNode: SKSpriteNode!
    private var sodaNode: SKSpriteNode!
    private var isGoodCherry: Bool = true // 現在のチェリーが良いチェリーか
    
    private var gameStarted: Bool = false // ゲームが開始しているか
    private var gameEnded: Bool = false   // ゲームが終了しているか
    
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        
        backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        
        // 物理エンジンの設定
        physicsWorld.gravity = CGVector(dx: 0, dy: -2.0) // 重力を設定 (強さ調整可能)
        physicsWorld.contactDelegate = self // 衝突検知のデリゲートを設定
        
        setupGround() // 地面ノードの追加
        setupSoda()
        setupScoreLabel()
        
        // 最初はcherryを表示せず、ゲーム開始を待つ
        // cherryを生成し、落下させるのはゲーム開始（最初のタップ）後
        // createCherry() // この時点ではまだ作らない
        
        // ゲーム開始を促すラベル
        let startLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        startLabel.text = "Tap to Start!"
        startLabel.fontColor = .darkGray
        startLabel.position = CGPoint(x: frame.midX, y: frame.midY + 200)
        startLabel.name = "startLabel"
        addChild(startLabel)
    }
    
    
    
    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .darkGray
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 350 )
        scoreLabel.zPosition = 10 // 最前面に表示
        addChild(scoreLabel)
    }
    
    private func setupSoda() {
        sodaNode = SKSpriteNode(imageNamed: "sodafloat") // soda.png を使用
        sodaNode.position = CGPoint(x: frame.midX, y: frame.minY + sodaNode.size.height / 2) // 画面下部に配置
        sodaNode.zPosition = 5 // cherryより手前
        addChild(sodaNode)
        
        // sodaの物理ボディを設定 (静的、当たり判定のみ)
        // 画像の形に合わせた物理ボディを作成する場合 (SKPhysicsBody(texture:size:))
        // または、四角形で当たり判定を限定する場合 (soda.frameを参考に)
        sodaNode.physicsBody = SKPhysicsBody(rectangleOf: sodaNode.size) // 四角形で作成
        sodaNode.physicsBody?.isDynamic = false // 動かないようにする
        sodaNode.physicsBody?.categoryBitMask = PhysicsCategory.soda // sodaカテゴリに設定
        sodaNode.physicsBody?.collisionBitMask = PhysicsCategory.none // 他のオブジェクトとは衝突しない（物理的な動きはしない）
        sodaNode.physicsBody?.contactTestBitMask = PhysicsCategory.cherry // cherryとの接触を検知する
    }
    
    private func setupGround() {
        // 画面の下端に透明な地面ノードを設置
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
    
    private func createCherry() {
        // 既存のcherryがあれば削除
        cherryNode?.removeFromParent()
        
        // ランダムに良いチェリーか悪いチェリーかを決定
        isGoodCherry = arc4random_uniform(2) == 0 // 0なら良いチェリー
        let imageName = isGoodCherry ? "cherry" : "badcherry"
        
        cherryNode = SKSpriteNode(imageNamed: imageName)
        cherryNode.size = CGSize(width: 300, height: 300)
        
        // cherryの初期位置（画面上部中央）
        cherryNode.position = CGPoint(x: frame.midX + 65, y: frame.maxY + cherryNode.size.height / 2)
        cherryNode.zPosition = 6 // sodaより少し手前
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
                                     height: sodaNode.frame.height / 5) // sodaの高さの半分
        
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
        
        cherryNode?.removeFromParent()
        
        // タイマーなどがある場合はここで停止
        // cherryNode?.physicsBody?.isDynamic = false // cherryの動きを止める
        
        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        gameOverLabel.text = "Game Over! Score: \(score)"
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY + 250)
        gameOverLabel.name = "gameOverLabel"
        addChild(gameOverLabel)
        
        let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        restartLabel.text = "Tap to Restart"
        restartLabel.fontSize = 25
        restartLabel.fontColor = .darkGray
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
        let startLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        startLabel.text = "Tap to Start!"
        startLabel.fontSize = 40
        startLabel.fontColor = .darkGray
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
                    cherryNode.removeFromParent()
                    // 少しディレイを置いて次のcherryを生成
                    run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                        self?.createCherry()
                    }
                }
            }
        }
        
    
    }
    
}
