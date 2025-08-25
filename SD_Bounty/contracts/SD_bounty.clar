;; Space Debris Bounty Hunter - Orbital Cleanup Rewards System
;; Gamified space cleanup with bounties for verified debris removal missions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-mission-active (err u106))
(define-constant err-mission-expired (err u107))
(define-constant err-invalid-orbit (err u108))
(define-constant err-debris-claimed (err u109))
(define-constant err-fuel-depleted (err u110))
(define-constant err-equipment-damaged (err u111))
(define-constant err-verification-pending (err u112))

;; Orbit zones
(define-constant orbit-leo u1)      ;; Low Earth Orbit
(define-constant orbit-meo u2)      ;; Medium Earth Orbit
(define-constant orbit-geo u3)      ;; Geostationary Orbit
(define-constant orbit-heo u4)      ;; Highly Elliptical Orbit
(define-constant orbit-lunar u5)    ;; Lunar vicinity

;; Debris types
(define-constant debris-defunct-satellite u1)
(define-constant debris-rocket-body u2)
(define-constant debris-fragments u3)
(define-constant debris-paint-flecks u4)
(define-constant debris-mission-debris u5)

;; Data Variables
(define-data-var total-debris-tracked uint u0)
(define-data-var total-debris-removed uint u0)
(define-data-var total-bounties-paid uint u0)
(define-data-var active-hunters uint u0)
(define-data-var mission-counter uint u0)
(define-data-var base-bounty-rate uint u1000000) ;; 1 STX per kg
(define-data-var danger-multiplier uint u15000) ;; 1.5x for dangerous debris
(define-data-var verification-threshold uint u3)
(define-data-var fuel-cost-per-km uint u100)

;; Fungible tokens
(define-fungible-token space-credits)
(define-fungible-token rocket-fuel)

;; NFTs
(define-non-fungible-token hunter-license uint)
(define-non-fungible-token debris-claim uint)

;; Data Maps
;; Space debris catalog
(define-map space-debris
    uint
    {
        debris-id: (string-ascii 20),
        debris-type: uint,
        mass-kg: uint,
        orbit-zone: uint,
        altitude-km: uint,
        velocity-kms: uint,
        danger-level: uint,
        tracked-since: uint,
        claimed-by: (optional principal),
        removed: bool,
        bounty-value: uint
    }
)

;; Bounty hunters
(define-map bounty-hunters
    principal
    {
        callsign: (string-ascii 50),
        spacecraft-type: (string-ascii 50),
        license-level: uint,
        debris-captured: uint,
        total-mass-removed: uint,
        reputation-score: uint,
        fuel-remaining: uint,
        current-orbit: uint,
        equipment-health: uint,
        missions-completed: uint
    }
)

;; Active missions
(define-map cleanup-missions
    uint
    {
        hunter: principal,
        target-debris: (list 5 uint),
        mission-start: uint,
        mission-deadline: uint,
        fuel-allocated: uint,
        current-progress: uint,
        verification-status: uint,
        reward-pool: uint,
        danger-bonus: uint
    }
)

;; Verification records
(define-map mission-verifications
    { mission-id: uint, verifier: principal }
    {
        verification-time: uint,
        debris-confirmed: (list 5 uint),
        method-used: (string-ascii 100),
        confidence-score: uint,
        verified: bool
    }
)

;; Mission verification counts
(define-map mission-verification-counts
    uint
    { count: uint }
)

;; Orbital mechanics
(define-map orbital-transfers
    { from-orbit: uint, to-orbit: uint }
    {
        delta-v-required: uint,
        fuel-cost: uint,
        time-blocks: uint,
        danger-factor: uint
    }
)

;; Space agencies (sponsors)
(define-map space-agencies
    principal
    {
        agency-name: (string-ascii 100),
        debris-posted: uint,
        bounties-funded: uint,
        priority-orbits: (list 3 uint),
        total-investment: uint
    }
)

;; Equipment upgrades
(define-map hunter-equipment
    { hunter: principal, equipment-id: uint }
    {
        equipment-type: (string-ascii 50),
        capture-capacity: uint,
        fuel-efficiency: uint,
        durability: uint,
        special-ability: (optional (string-ascii 100))
    }
)

;; Read-only functions
(define-read-only (get-debris-info (debris-id uint))
    (map-get? space-debris debris-id)
)

(define-read-only (get-hunter-stats (hunter principal))
    (map-get? bounty-hunters hunter)
)

(define-read-only (get-mission (mission-id uint))
    (map-get? cleanup-missions mission-id)
)

(define-read-only (calculate-bounty (mass uint) (danger uint) (orbit uint))
    (let
        (
            (base-bounty (* mass (var-get base-bounty-rate)))
            (danger-bonus (/ (* base-bounty danger) u10))
            (orbit-bonus (if (is-eq orbit orbit-geo)
                            (/ (* base-bounty u20) u100) ;; 20% bonus for GEO
                            u0))
        )
        (ok (+ base-bounty danger-bonus orbit-bonus))
    )
)

(define-read-only (get-fuel-requirement (current-orbit uint) (target-orbit uint) (mass uint))
    (let
        (
            (transfer-data (map-get? orbital-transfers 
                          { from-orbit: current-orbit, to-orbit: target-orbit }))
        )
        (match transfer-data
            data (ok (+ (get fuel-cost data) (/ mass u100)))
            (ok u1000) ;; Default fuel cost
        )
    )
)

;; Private functions
(define-private (update-hunter-stats (hunter principal) (mass-removed uint) (reputation-gain uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats hunter) false))
        )
        (map-set bounty-hunters hunter
            (merge hunter-data {
                debris-captured: (+ (get debris-captured hunter-data) u1),
                total-mass-removed: (+ (get total-mass-removed hunter-data) mass-removed),
                reputation-score: (+ (get reputation-score hunter-data) reputation-gain),
                missions-completed: (+ (get missions-completed hunter-data) u1)
            })
        )
    )
)

(define-private (consume-fuel (hunter principal) (amount uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats hunter) false))
        )
        (if (>= (get fuel-remaining hunter-data) amount)
            (begin
                (map-set bounty-hunters hunter
                    (merge hunter-data {
                        fuel-remaining: (- (get fuel-remaining hunter-data) amount)
                    })
                )
                true
            )
            false
        )
    )
)

;; Helper function to get debris bounty
(define-private (get-debris-bounty (debris-id uint))
    (default-to u0 (get bounty-value (map-get? space-debris debris-id)))
)

;; Helper function to mark debris as claimed
(define-private (mark-debris-claimed (debris-id uint))
    (match (map-get? space-debris debris-id)
        debris-data (map-set space-debris debris-id
                        (merge debris-data { claimed-by: (some tx-sender) }))
        false
    )
)

;; Helper to get verification count
(define-private (get-verification-count (mission-id uint))
    (default-to u0 (get count (map-get? mission-verification-counts mission-id)))
)

;; Helper to mark debris as removed
(define-private (remove-debris (debris-id uint))
    (match (map-get? space-debris debris-id)
        debris-data (map-set space-debris debris-id
                        (merge debris-data { removed: true }))
        false
    )
)

;; Helper function for min
(define-private (min (a uint) (b uint))
    (if (< a b) a b)
)

;; Helper function to calculate total bounty for debris list
(define-private (calculate-total-bounty (debris-list (list 5 uint)))
    (fold + (map get-debris-bounty debris-list) u0)
)

;; Helper function to mark multiple debris as claimed
(define-private (mark-multiple-debris-claimed (debris-list (list 5 uint)))
    (fold mark-debris-claimed-fold debris-list true)
)

(define-private (mark-debris-claimed-fold (debris-id uint) (prev bool))
    (and prev (mark-debris-claimed debris-id))
)

;; Helper function to remove multiple debris
(define-private (remove-multiple-debris (debris-list (list 5 uint)))
    (fold remove-debris-fold debris-list true)
)

(define-private (remove-debris-fold (debris-id uint) (prev bool))
    (and prev (remove-debris debris-id))
)

;; Public functions

;; Register as bounty hunter
(define-public (register-hunter 
    (callsign (string-ascii 50))
    (spacecraft (string-ascii 50)))
    (let
        (
            (license-id (var-get active-hunters))
        )
        ;; Check not already registered
        (asserts! (is-none (get-hunter-stats tx-sender)) err-already-registered)
        
        ;; Register hunter
        (map-set bounty-hunters tx-sender {
            callsign: callsign,
            spacecraft-type: spacecraft,
            license-level: u1,
            debris-captured: u0,
            total-mass-removed: u0,
            reputation-score: u100,
            fuel-remaining: u10000,
            current-orbit: orbit-leo,
            equipment-health: u100,
            missions-completed: u0
        })
        
        ;; Mint hunter license NFT
        (try! (nft-mint? hunter-license license-id tx-sender))
        
        ;; Mint initial resources
        (try! (ft-mint? space-credits u1000 tx-sender))
        (try! (ft-mint? rocket-fuel u10000 tx-sender))
        
        ;; Update counter
        (var-set active-hunters (+ license-id u1))
        
        (ok license-id)
    )
)

;; Post debris bounty
(define-public (post-debris-bounty
    (debris-designation (string-ascii 20))
    (mass uint)
    (orbit uint)
    (altitude uint)
    (velocity uint)
    (danger uint)
    (bounty-amount uint))
    (let
        (
            (debris-id (+ (var-get total-debris-tracked) u1))
        )
        ;; Transfer bounty to contract
        (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
        
        ;; Create debris entry
        (map-set space-debris debris-id {
            debris-id: debris-designation,
            debris-type: debris-defunct-satellite,
            mass-kg: mass,
            orbit-zone: orbit,
            altitude-km: altitude,
            velocity-kms: velocity,
            danger-level: danger,
            tracked-since: stacks-block-height,
            claimed-by: none,
            removed: false,
            bounty-value: bounty-amount
        })
        
        ;; Update tracking
        (var-set total-debris-tracked debris-id)
        (var-set total-bounties-paid (+ (var-get total-bounties-paid) bounty-amount))
        
        (ok debris-id)
    )
)

;; Claim debris for removal mission
(define-public (claim-debris-targets (targets (list 5 uint)) (fuel-allocation uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats tx-sender) err-not-found))
            (mission-id (var-get mission-counter))
            (total-bounty (calculate-total-bounty targets))
        )
        ;; Validate hunter has enough fuel
        (asserts! (>= (get fuel-remaining hunter-data) fuel-allocation) err-fuel-depleted)
        
        ;; Consume fuel
        (asserts! (consume-fuel tx-sender fuel-allocation) err-fuel-depleted)
        
        ;; Create mission
        (map-set cleanup-missions mission-id {
            hunter: tx-sender,
            target-debris: targets,
            mission-start: stacks-block-height,
            mission-deadline: (+ stacks-block-height u1440), ;; ~10 days
            fuel-allocated: fuel-allocation,
            current-progress: u0,
            verification-status: u0,
            reward-pool: total-bounty,
            danger-bonus: u0
        })
        
        ;; Mark debris as claimed
        (asserts! (mark-multiple-debris-claimed targets) err-debris-claimed)
        
        ;; Mint claim NFT
        (try! (nft-mint? debris-claim mission-id tx-sender))
        
        ;; Update mission counter
        (var-set mission-counter (+ mission-id u1))
        
        (ok mission-id)
    )
)

;; Submit mission completion proof
(define-public (submit-removal-proof 
    (mission-id uint)
    (removal-method (string-ascii 100))
    (proof-hash (string-ascii 100)))
    (let
        (
            (mission (unwrap! (get-mission mission-id) err-not-found))
        )
        ;; Validations
        (asserts! (is-eq tx-sender (get hunter mission)) err-unauthorized)
        (asserts! (< stacks-block-height (get mission-deadline mission)) err-mission-expired)
        (asserts! (is-eq (get verification-status mission) u0) err-verification-pending)
        
        ;; Update mission
        (map-set cleanup-missions mission-id
            (merge mission {
                verification-status: u1, ;; Pending verification
                current-progress: (len (get target-debris mission))
            })
        )
        
        (ok true)
    )
)

;; Verify mission completion
(define-public (verify-mission 
    (mission-id uint)
    (confirmed-debris (list 5 uint))
    (confidence uint))
    (let
        (
            (mission (unwrap! (get-mission mission-id) err-not-found))
            (current-count (get-verification-count mission-id))
            (new-count (+ current-count u1))
        )
        ;; Record verification
        (map-set mission-verifications
            { mission-id: mission-id, verifier: tx-sender }
            {
                verification-time: stacks-block-height,
                debris-confirmed: confirmed-debris,
                method-used: "orbital-tracking",
                confidence-score: confidence,
                verified: true
            }
        )
        
        ;; Update verification count
        (map-set mission-verification-counts mission-id { count: new-count })
        
        ;; Check if threshold reached
        (if (>= new-count (var-get verification-threshold))
            (complete-mission mission-id)
            (ok false)
        )
    )
)

;; Complete mission and distribute rewards
(define-private (complete-mission (mission-id uint))
    (let
        (
            (mission (unwrap! (get-mission mission-id) (ok false)))
            (hunter-data (unwrap! (get-hunter-stats (get hunter mission)) (ok false)))
        )
        ;; Transfer bounty
        (try! (as-contract (stx-transfer? (get reward-pool mission) 
                                         tx-sender 
                                         (get hunter mission))))
        
        ;; Update debris status
        (asserts! (remove-multiple-debris (get target-debris mission)) (ok false))
        
        ;; Update hunter stats
        (update-hunter-stats (get hunter mission) u100 u50) ;; Example values
        
        ;; Update global counters
        (var-set total-debris-removed (+ (var-get total-debris-removed) 
                                        (len (get target-debris mission))))
        
        ;; Update mission status
        (map-set cleanup-missions mission-id
            (merge mission { verification-status: u2 })) ;; Completed
        
        (ok true)
    )
)

;; Refuel spacecraft
(define-public (refuel-spacecraft (fuel-amount uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats tx-sender) err-not-found))
            (fuel-cost (/ (* fuel-amount (var-get fuel-cost-per-km)) u1000))
        )
        ;; Pay for fuel
        (try! (stx-transfer? fuel-cost tx-sender (as-contract tx-sender)))
        
        ;; Update fuel
        (map-set bounty-hunters tx-sender
            (merge hunter-data {
                fuel-remaining: (+ (get fuel-remaining hunter-data) fuel-amount)
            })
        )
        
        ;; Mint fuel tokens
        (try! (ft-mint? rocket-fuel fuel-amount tx-sender))
        
        (ok fuel-amount)
    )
)

;; Change orbit
(define-public (change-orbit (target-orbit uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats tx-sender) err-not-found))
            (current-orbit-zone (get current-orbit hunter-data))
            (fuel-required (unwrap! (get-fuel-requirement current-orbit-zone target-orbit u100) 
                                   err-invalid-amount))
        )
        ;; Check fuel
        (asserts! (>= (get fuel-remaining hunter-data) fuel-required) err-fuel-depleted)
        
        ;; Consume fuel
        (asserts! (consume-fuel tx-sender fuel-required) err-fuel-depleted)
        
        ;; Update orbit
        (map-set bounty-hunters tx-sender
            (merge hunter-data {
                current-orbit: target-orbit
            })
        )
        
        (ok target-orbit)
    )
)

;; Repair equipment
(define-public (repair-equipment (repair-amount uint))
    (let
        (
            (hunter-data (unwrap! (get-hunter-stats tx-sender) err-not-found))
            (repair-cost (* repair-amount u100000))
        )
        ;; Pay for repairs
        (try! (stx-transfer? repair-cost tx-sender (as-contract tx-sender)))
        
        ;; Update equipment health
        (map-set bounty-hunters tx-sender
            (merge hunter-data {
                equipment-health: (min u100 (+ (get equipment-health hunter-data) repair-amount))
            })
        )
        
        (ok true)
    )
)

;; Initialize orbital transfer costs (owner only)
(define-public (set-orbital-transfer 
    (from uint) 
    (to uint) 
    (delta-v uint) 
    (fuel uint) 
    (time uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set orbital-transfers
            { from-orbit: from, to-orbit: to }
            {
                delta-v-required: delta-v,
                fuel-cost: fuel,
                time-blocks: time,
                danger-factor: u10
            }
        )
        
        (ok true)
    )
)