# **Comprehensive Guide to Setting Up Your Hyperledger Fabric Network**

## **Prerequisites**

Before starting, ensure you have the following installed on your local machine and servers:

- **Local Machine:**
  - Go programming language (version 1.16 or later)
  - Docker and Docker Compose
  - Hyperledger Fabric binaries (e.g., `cryptogen`, `configtxgen`, `peer` CLI)
  - OpenSSL (for generating certificates if needed)
  - Secure Shell (SSH) access to your servers

- **Servers (Orderer and Peers):**
  - Docker and Docker Compose installed
  - Properly configured DNS entries for your domain names

---

## **1. Set Up Domain Names and DNS**

- **Register Domain Names**: Ensure you have registered the following domain names:

  - `orderer.fabriczakat.tech`
  - `peer0.ydsfmalang.fabriczakat.tech`
  - `peer0.ydsfjatim.fabriczakat.tech`

- **Configure DNS**: Use your DNS provider (e.g., Cloudflare) to point these domain names to the public IP addresses of your servers.

  - **Orderer Server** (`orderer.fabriczakat.tech`): `157.230.250.207`
  - **YDSF Malang Peer** (`peer0.ydsfmalang.fabriczakat.tech`): `103.127.134.234`
  - **YDSF Jatim Peer** (`peer0.ydsfjatim.fabriczakat.tech`): `206.189.156.160`

- **Verify DNS Resolution**:

  ```bash
  nslookup orderer.fabriczakat.tech
  nslookup peer0.ydsfmalang.fabriczakat.tech
  nslookup peer0.ydsfjatim.fabriczakat.tech
  ```

---

## **2. Create `crypto-config.yaml`**

Create a file named `crypto-config.yaml` in your project directory with the following content:

```yaml
###############################################################################
#
#   Crypto Configuration
#
###############################################################################

OrdererOrgs:
  - Name: OrdererOrg
    Domain: fabriczakat.tech
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer
        SANS:
          - orderer.fabriczakat.tech

PeerOrgs:
  - Name: YDSFMalang
    Domain: ydsfmalang.fabriczakat.tech
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - peer0.ydsfmalang.fabriczakat.tech
    Users:
      Count: 1

  - Name: YDSFJatim
    Domain: ydsfjatim.fabriczakat.tech
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - peer0.ydsfjatim.fabriczakat.tech
    Users:
      Count: 1
```

**Notes**:

- The `SANS` field includes your domain names, ensuring the certificates are valid for your hostnames.
- Adjust the paths and counts if necessary.

---

## **3. Generate Cryptographic Materials with `cryptogen`**

- **Set the Fabric Configuration Path**:

  ```bash
  export FABRIC_CFG_PATH=$PWD
  ```

- **Generate the Crypto Material**:

  ```bash
  cryptogen generate --config=./crypto-config.yaml --output=./organizations
  ```

- **Verify the Generated Files**:

  ```bash
  tree -L 3 organizations/
  ```

---

## **4. Create `configtx.yaml`**

Create a file named `configtx.yaml` with the following content:

```yaml
################################################################################
#
#   Section: Organizations
#
################################################################################
Organizations:

    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: ./organizations/ordererOrganizations/fabriczakat.tech/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Writers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Admins:
                Type: Signature
                Rule: "OR('OrdererMSP.admin')"
        OrdererEndpoints:
            - orderer.fabriczakat.tech:7050

    - &YDSFMalang
        Name: YDSFMalangMSP
        ID: YDSFMalangMSP
        MSPDir: ./organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('YDSFMalangMSP.admin', 'YDSFMalangMSP.peer', 'YDSFMalangMSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('YDSFMalangMSP.admin', 'YDSFMalangMSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('YDSFMalangMSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('YDSFMalangMSP.peer')"
        AnchorPeers:
          - Host: peer0.ydsfmalang.fabriczakat.tech
            Port: 7051

    - &YDSFJatim
        Name: YDSFJatimMSP
        ID: YDSFJatimMSP
        MSPDir: ./organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('YDSFJatimMSP.admin', 'YDSFJatimMSP.peer', 'YDSFJatimMSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('YDSFJatimMSP.admin', 'YDSFJatimMSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('YDSFJatimMSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('YDSFJatimMSP.peer')"
        AnchorPeers:
          - Host: peer0.ydsfjatim.fabriczakat.tech
            Port: 7051

################################################################################
#
#   SECTION: Capabilities
#
################################################################################
Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true

################################################################################
#
#   SECTION: Application
#
################################################################################
Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
    Capabilities:
        <<: *ApplicationCapabilities

################################################################################
#
#   SECTION: Orderer
#
################################################################################
Orderer: &OrdererDefaults
  OrdererType: etcdraft
  Addresses:
    - orderer.fabriczakat.tech:7050
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  EtcdRaft:
    Consenters:
      - Host: orderer.fabriczakat.tech
        Port: 7050
        ClientTLSCert: ./organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/tls/server.crt
        ServerTLSCert: ./organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/tls/server.crt
  Organizations:
    - *OrdererOrg
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    <<: *OrdererCapabilities

################################################################################
#
#   SECTION: Channel
#
################################################################################
Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
    Capabilities:
        <<: *ChannelCapabilities

################################################################################
#
#   SECTION: Profiles
#
################################################################################
Profiles:

    ZakatGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
        Consortiums:
            ZakatConsortium:
                Organizations:
                    - *YDSFMalang
                    - *YDSFJatim

    ZakatChannel:
        <<: *ChannelDefaults
        Consortium: ZakatConsortium
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *YDSFMalang
                - *YDSFJatim
            Capabilities:
                <<: *ApplicationCapabilities
```

**Notes**:

- Ensure that the paths in `MSPDir`, `ClientTLSCert`, and `ServerTLSCert` are correct relative to your `FABRIC_CFG_PATH`.
- The `Orderer` section now correctly places `BatchTimeout`, `BatchSize`, `Organizations`, `Policies`, and `Capabilities` directly under `Orderer`.
- The `EtcdRaft` section contains only the `Consenters` key.

---

## **5. Generate Genesis Block and Channel Artifacts**

- **Set the Fabric Configuration Path**:

  ```bash
  export FABRIC_CFG_PATH=$PWD
  ```

- **Create Directories for Output**:

  ```bash
  mkdir system-genesis-block
  mkdir channel-artifacts
  ```

- **Generate the Genesis Block**:

  ```bash
  configtxgen -profile ZakatGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  ```

- **Generate the Channel Creation Transaction**:

  ```bash
  configtxgen -profile ZakatChannel -outputCreateChannelTx ./channel-artifacts/zakat-channel.tx -channelID zakat-channel
  ```

- **Generate Anchor Peer Updates**:

  ```bash
  configtxgen -profile ZakatChannel -outputAnchorPeersUpdate ./channel-artifacts/YDSFMalangMSPanchors.tx -channelID zakat-channel -asOrg YDSFMalangMSP

  configtxgen -profile ZakatChannel -outputAnchorPeersUpdate ./channel-artifacts/YDSFJatimMSPanchors.tx -channelID zakat-channel -asOrg YDSFJatimMSP
  ```

- **Verify the Generated Files**:

  ```bash
  ls system-genesis-block/
  ls channel-artifacts/
  ```

---

## **6. Distribute Cryptographic Materials and Artifacts to Servers**

### **Orderer Server (`orderer.fabriczakat.tech`)**

- **Transfer Directories**:

  ```bash
  scp -r organizations/ordererOrganizations username@orderer.fabriczakat.tech:/home/username/fabric-zakat/organizations/
  ```

- **Transfer Genesis Block**:

  ```bash
  scp system-genesis-block/genesis.block username@orderer.fabriczakat.tech:/home/username/fabric-zakat/system-genesis-block/
  ```

### **YDSF Malang Peer Server (`peer0.ydsfmalang.fabriczakat.tech`)**

- **Transfer Directories**:

  ```bash
  scp -r organizations/peerOrganizations/ydsfmalang.fabriczakat.tech username@peer0.ydsfmalang.fabriczakat.tech:/home/username/fabric-zakat/organizations/peerOrganizations/
  ```

- **Transfer Channel Artifacts**:

  ```bash
  scp channel-artifacts/zakat-channel.tx username@peer0.ydsfmalang.fabriczakat.tech:/home/username/fabric-zakat/channel-artifacts/
  scp channel-artifacts/YDSFMalangMSPanchors.tx username@peer0.ydsfmalang.fabriczakat.tech:/home/username/fabric-zakat/channel-artifacts/
  ```

### **YDSF Jatim Peer Server (`peer0.ydsfjatim.fabriczakat.tech`)**

- **Transfer Directories**:

  ```bash
  scp -r organizations/peerOrganizations/ydsfjatim.fabriczakat.tech username@peer0.ydsfjatim.fabriczakat.tech:/home/username/fabric-zakat/organizations/peerOrganizations/
  ```

- **Transfer Channel Artifacts**:

  ```bash
  scp channel-artifacts/zakat-channel.tx username@peer0.ydsfjatim.fabriczakat.tech:/home/username/fabric-zakat/channel-artifacts/
  scp channel-artifacts/YDSFJatimMSPanchors.tx username@peer0.ydsfjatim.fabriczakat.tech:/home/username/fabric-zakat/channel-artifacts/
  ```

**Notes**:

- Replace `username` with your actual username on the servers.
- Ensure that the destination directories exist on the servers.
- Use `rsync` if you prefer.

---

## **7. Prepare Docker Compose Files**

### **Orderer Docker Compose (`docker-compose-orderer.yaml`)**

```yaml
version: '2'

services:

  orderer.fabriczakat.tech:
    image: hyperledger/fabric-orderer:2.2
    container_name: orderer.fabriczakat.tech
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file
      - ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true
    command: orderer
    volumes:
      - /home/username/fabric-zakat/system-genesis-block/genesis.block:/var/hyperledger/orderer/genesis.block
      - /home/username/fabric-zakat/organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/msp:/var/hyperledger/orderer/msp
      - /home/username/fabric-zakat/organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/tls:/var/hyperledger/orderer/tls
      - orderer.fabriczakat.tech:/var/hyperledger/production/orderer
    ports:
      - 7050:7050
    networks:
      - fabric_network

volumes:
  orderer.fabriczakat.tech:

networks:
  fabric_network:
```

### **YDSF Malang Peer Docker Compose (`docker-compose-ydsfmalang.yaml`)**

```yaml
version: '2'

services:

  peer0.ydsfmalang.fabriczakat.tech:
    image: hyperledger/fabric-peer:2.2
    container_name: peer0.ydsfmalang.fabriczakat.tech
    environment:
      - CORE_PEER_ID=peer0.ydsfmalang.fabriczakat.tech
      - CORE_PEER_ADDRESS=0.0.0.0:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=0.0.0.0:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.ydsfmalang.fabriczakat.tech:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.ydsfmalang.fabriczakat.tech:7051
      - CORE_PEER_LOCALMSPID=YDSFMalangMSP
      - CORE_PEER_MSPCONFIGPATH=/var/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/var/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/var/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/peer/tls/ca.crt
    command: peer node start
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - /home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/peers/peer0.ydsfmalang.fabriczakat.tech/msp:/var/hyperledger/peer/msp
      - /home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/peers/peer0.ydsfmalang.fabriczakat.tech/tls:/var/hyperledger/peer/tls
      - peer0.ydsfmalang.fabriczakat.tech:/var/hyperledger/production
    ports:
      - 7051:7051
      - 7052:7052
      - 7053:7053
    networks:
      - fabric_network

volumes:
  peer0.ydsfmalang.fabriczakat.tech:

networks:
  fabric_network:
```

### **YDSF Jatim Peer Docker Compose (`docker-compose-ydsfjatim.yaml`)**

```yaml
version: '2'

services:

  peer0.ydsfjatim.fabriczakat.tech:
    image: hyperledger/fabric-peer:2.2
    container_name: peer0.ydsfjatim.fabriczakat.tech
    environment:
      - CORE_PEER_ID=peer0.ydsfjatim.fabriczakat.tech
      - CORE_PEER_ADDRESS=0.0.0.0:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=0.0.0.0:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.ydsfjatim.fabriczakat.tech:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.ydsfmalang.fabriczakat.tech:7051
      - CORE_PEER_LOCALMSPID=YDSFJatimMSP
      - CORE_PEER_MSPCONFIGPATH=/var/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/var/hyperledger/peer/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/var/hyperledger/peer/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/peer/tls/ca.crt
    command: peer node start
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - /home/username/fabric-zakat/organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/peers/peer0.ydsfjatim.fabriczakat.tech/msp:/var/hyperledger/peer/msp
      - /home/username/fabric-zakat/organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/peers/peer0.ydsfjatim.fabriczakat.tech/tls:/var/hyperledger/peer/tls
      - peer0.ydsfjatim.fabriczakat.tech:/var/hyperledger/production
    ports:
      - 7051:7051
      - 7052:7052
      - 7053:7053
    networks:
      - fabric_network

volumes:
  peer0.ydsfjatim.fabriczakat.tech:

networks:
  fabric_network:
```

**Notes**:

- Ensure that the volume paths match the locations on your servers.
- Use domain names in environment variables instead of IP addresses.
- Mount the Docker socket (`/var/run/docker.sock`) if you're using the default chaincode launcher.

---

## **8. Start the Orderer and Peers**

### **Orderer Server**

- **Navigate to the Directory**:

  ```bash
  cd /home/username/fabric-zakat/
  ```

- **Start the Orderer**:

  ```bash
  docker-compose -f docker-compose-orderer.yaml up -d
  ```

### **YDSF Malang Peer Server**

- **Navigate to the Directory**:

  ```bash
  cd /home/username/fabric-zakat/
  ```

- **Start the Peer**:

  ```bash
  docker-compose -f docker-compose-ydsfmalang.yaml up -d
  ```

### **YDSF Jatim Peer Server**

- **Navigate to the Directory**:

  ```bash
  cd /home/username/fabric-zakat/
  ```

- **Start the Peer**:

  ```bash
  docker-compose -f docker-compose-ydsfjatim.yaml up -d
  ```

**Verify Containers are Running**:

```bash
docker ps
```

---

## **9. Create the Channel**

Perform this step on **YDSF Malang Peer Server** or any peer server with the `peer` CLI installed.

- **Set Environment Variables**:

  ```bash
  export CORE_PEER_LOCALMSPID=YDSFMalangMSP
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/peers/peer0.ydsfmalang.fabriczakat.tech/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/users/Admin@ydsfmalang.fabriczakat.tech/msp
  export CORE_PEER_ADDRESS=localhost:7051
  export CORE_PEER_TLS_ENABLED=true
  export ORDERER_CA=/home/username/fabric-zakat/organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/msp/tlscacerts/tlsca.fabriczakat.tech-cert.pem
  ```

- **Create the Channel**:

  ```bash
  peer channel create -o orderer.fabriczakat.tech:7050 -c zakat-channel -f /home/username/fabric-zakat/channel-artifacts/zakat-channel.tx --outputBlock /home/username/fabric-zakat/zakat-channel.block --tls --cafile $ORDERER_CA
  ```

---

## **10. Join Peers to the Channel**

### **YDSF Malang Peer Server**

- **Set Environment Variables** (if not already set):

  ```bash
  export CORE_PEER_LOCALMSPID=YDSFMalangMSP
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/peers/peer0.ydsfmalang.fabriczakat.tech/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/users/Admin@ydsfmalang.fabriczakat.tech/msp
  export CORE_PEER_ADDRESS=localhost:7051
  export CORE_PEER_TLS_ENABLED=true
  ```

- **Join the Channel**:

  ```bash
  peer channel join -b /home/username/fabric-zakat/zakat-channel.block
  ```

### **YDSF Jatim Peer Server**

- **Transfer Channel Block**:

  - From YDSF Malang Peer Server:

    ```bash
    scp /home/username/fabric-zakat/zakat-channel.block username@peer0.ydsfjatim.fabriczakat.tech:/home/username/fabric-zakat/
    ```

- **Set Environment Variables**:

  ```bash
  export CORE_PEER_LOCALMSPID=YDSFJatimMSP
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/peers/peer0.ydsfjatim.fabriczakat.tech/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/username/fabric-zakat/organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/users/Admin@ydsfjatim.fabriczakat.tech/msp
  export CORE_PEER_ADDRESS=localhost:7051
  export CORE_PEER_TLS_ENABLED=true
  export ORDERER_CA=/home/username/fabric-zakat/organizations/ordererOrganizations/fabriczakat.tech/orderers/orderer.fabriczakat.tech/msp/tlscacerts/tlsca.fabriczakat.tech-cert.pem
  ```

- **Join the Channel**:

  ```bash
  peer channel join -b /home/username/fabric-zakat/zakat-channel.block
  ```

---

## **11. Update Anchor Peers**

### **YDSF Malang Peer Server**

- **Set Environment Variables** (if not already set).
- **Update Anchor Peer**:

  ```bash
  peer channel update -o orderer.fabriczakat.tech:7050 -c zakat-channel -f /home/username/fabric-zakat/channel-artifacts/YDSFMalangMSPanchors.tx --tls --cafile $ORDERER_CA
  ```

### **YDSF Jatim Peer Server**

- **Set Environment Variables** (if not already set).
- **Update Anchor Peer**:

  ```bash
  peer channel update -o orderer.fabriczakat.tech:7050 -c zakat-channel -f /home/username/fabric-zakat/channel-artifacts/YDSFJatimMSPanchors.tx --tls --cafile $ORDERER_CA
  ```

---

## **12. Install and Approve Chaincode**

### **Package the Chaincode**

- **On Local Machine**:

  ```bash
  peer lifecycle chaincode package mychaincode.tar.gz --path ./chaincode --lang golang --label mychaincode_1
  ```

- **Transfer Chaincode Package to Peer Servers**:

  ```bash
  scp mychaincode.tar.gz username@peer0.ydsfmalang.fabriczakat.tech:/home/username/fabric-zakat/chaincode/
  scp mychaincode.tar.gz username@peer0.ydsfjatim.fabriczakat.tech:/home/username/fabric-zakat/chaincode/
  ```

### **Install Chaincode on Peers**

- **Set Environment Variables** (on each peer server).
- **Install Chaincode**:

  ```bash
  peer lifecycle chaincode install /home/username/fabric-zakat/chaincode/mychaincode.tar.gz
  ```

### **Approve Chaincode for Organizations**

- **Query Installed Chaincode**:

  ```bash
  peer lifecycle chaincode queryinstalled
  ```

- **Set Variables**:

  - Use the package ID from the previous command.
  - For example:

    ```bash
    export CC_PACKAGE_ID=mychaincode_1:abc123...
    ```

- **Approve Chaincode Definition**:

  ```bash
  peer lifecycle chaincode approveformyorg --orderer orderer.fabriczakat.tech:7050 --channelID zakat-channel --name mychaincode --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA
  ```

### **Commit Chaincode Definition**

- **Commit Chaincode**:

  ```bash
  peer lifecycle chaincode commit -o orderer.fabriczakat.tech:7050 --channelID zakat-channel --name mychaincode --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA --peerAddresses peer0.ydsfmalang.fabriczakat.tech:7051 --tlsRootCertFiles /home/username/fabric-zakat/organizations/peerOrganizations/ydsfmalang.fabriczakat.tech/peers/peer0.ydsfmalang.fabriczakat.tech/tls/ca.crt --peerAddresses peer0.ydsfjatim.fabriczakat.tech:7051 --tlsRootCertFiles /home/username/fabric-zakat/organizations/peerOrganizations/ydsfjatim.fabriczakat.tech/peers/peer0.ydsfjatim.fabriczakat.tech/tls/ca.crt
  ```

---

## **13. Test the Network**

- **Invoke Chaincode**:

  ```bash
  peer chaincode invoke -o orderer.fabriczakat.tech:7050 --isInit -C zakat-channel -n mychaincode --tls --cafile $ORDERER_CA -c '{"Args":["InitLedger"]}'
  ```

- **Query Chaincode**:

  ```bash
  peer chaincode query -C zakat-channel -n mychaincode -c '{"Args":["QueryAllAssets"]}'
  ```

---

## **14. Firewall and Security Considerations**

- **Open Necessary Ports**:

  - **Orderer**: Port `7050`
  - **Peers**: Ports `7051`, `7052`, `7053`

- **TLS Communication**:

  - Ensure that TLS certificates are correctly configured and included in the environment variables.

- **Secure Cryptographic Materials**:

  - Restrict permissions on private keys and sensitive files.

---

## **15. Monitoring and Troubleshooting**

- **Check Logs**:

  ```bash
  docker logs orderer.fabriczakat.tech
  docker logs peer0.ydsfmalang.fabriczakat.tech
  docker logs peer0.ydsfjatim.fabriczakat.tech
  ```

- **Verify Connectivity**:

  - Use `ping` or `telnet` to verify that the nodes can reach each other on the required ports.

- **Common Issues**:

  - **DNS Resolution**: Ensure that domain names resolve correctly.
  - **Firewall Rules**: Check that firewalls allow necessary traffic.
  - **Certificate Errors**: Verify that certificates include correct SAN entries.

---

## **16. Additional Tips**

- **Documentation**: Keep detailed records of your configurations and steps taken.
- **Backup**: Securely back up your cryptographic materials and configurations.
- **Automation**: Consider automating repetitive tasks with scripts or tools like Ansible.
- **Updates**: Keep your Hyperledger Fabric binaries and Docker images up to date.

---

## **Conclusion**

By following this step-by-step guide, you should have a fully operational Hyperledger Fabric network with your orderer and peer nodes up and running across multiple servers. Remember to maintain consistency in your configurations, secure your cryptographic materials, and monitor your network for any issues.
