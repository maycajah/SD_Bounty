# Space Debris Bounty Hunter 🚀🛰️

## Description

A **gamified orbital cleanup system** where bounty hunters are rewarded with **tokens, fuel, and reputation** for removing **dangerous space debris**.
Players take missions, track and capture debris, and get verified by orbital agencies before claiming bounties.

## Installation / Deployment

```sh
clarinet check
clarinet deploy
```

## Features

* **Hunter Registry** → Register spacecraft & callsign, mint license NFT
* **Debris Catalog** → Post and track space debris with bounty funding
* **Mission System** → Claim multiple debris targets, allocate fuel, earn rewards
* **Verification Layer** → Independent verifiers confirm debris removal
* **Bounty Rewards** → Earn STX payouts + NFTs for successful cleanup
* **Fuel & Orbit Mechanics** → Manage fuel, orbital transfers, repairs
* **Equipment System** → Upgrade and repair spacecraft gear
* **Agency Sponsors** → Space agencies can fund bounties and set priorities

## Usage

### Hunters

* `register-hunter(callsign, spacecraft)` → Register & mint license NFT
* `get-hunter-stats(hunter)` → View hunter profile

### Debris & Bounties

* `post-debris-bounty(designation, mass, orbit, altitude, velocity, danger, bounty)`
* `get-debris-info(debris-id)` → Retrieve debris data

### Missions

* `claim-debris-targets(targets, fuel-allocation)` → Start cleanup mission
* `submit-removal-proof(mission-id, method, proof-hash)` → Submit completion evidence
* `verify-mission(mission-id, confirmed-debris, confidence)` → Verifiers confirm mission
* **Auto payout** when verification threshold reached

### Fuel & Orbit

* `refuel-spacecraft(fuel-amount)` → Buy additional rocket fuel
* `change-orbit(target-orbit)` → Spend fuel to switch orbit zones

### Equipment

* `repair-equipment(amount)` → Pay to repair spacecraft health

### Orbital Transfer Setup (Owner Only)

* `set-orbital-transfer(from, to, delta-v, fuel, time)` → Configure orbital mechanics

### Read-Only Queries

* `get-mission(mission-id)` → Fetch mission data
* `calculate-bounty(mass, danger, orbit)` → Estimate payout
* `get-fuel-requirement(current-orbit, target-orbit, mass)` → Fuel calculation

---

🌍 **Clean up space. Earn bounties. Protect the future of orbital exploration.**
