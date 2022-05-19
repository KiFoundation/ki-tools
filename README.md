<p align="right">
    <img width=150px src="https://wallet-testnet.blockchain.ki/static/img/icons/ki-chain.png" />
</p>

# Ki Tools

This repository hosts `kid`, the implementation of the kichain protocol, based on Cosmos-SDK.

## Quick Start

### Install Golang (linux)

To install Go, visit the Go download page and copy the link of the latest Go release for Linux systems, download and unzip the archive file as follows:

```bash
wget https://dl.google.com/go/go1.17.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.17.linux-amd64.tar.gz
```

Finally, export the Go paths like so:

```bash
mkdir -p $HOME/go/bin
PATH=$PATH:/usr/local/go/bin
echo "export PATH=$PATH:$(go env GOPATH)/bin" >> ~/.bash_profile
source ~/.bash_profile
```

To test the Go installation,  use the `version` command to check the downloaded version as follows :

```bash
go version
```

This should output :

```bash
go version go1.17 linux/amd64
```

### Build kid (linux)

Start by cloning this repository. If you are here, you most likely have git installed already, otherwise just run:

```bash
sudo apt install git
```

And now you can clone the repository as follows:

```bash
git clone https://github.com/KiFoundation/ki-tools.git
```

If your are starting with a clean ubuntu install you might need to install the `build-essential` package:

```bash
sudo apt update
sudo apt install build-essential
```

Finally, navigate to the repository folder and install the tools as follows:

```bash
cd ki-tools
make install
```

To test the installation, check the downloaded version as follows:

```bash
kid version --long
```

### Building for testnet

Testnet token name (tki) is different from mainnet (xki). Testnet binaries need to support this difference.
To build a testnet binary, run as follows:

```bash
cd ki-tools
make build-testnet
```

You can also build a static testnet binary as explained in the following section.

### Build a static kid binary

#### **Why building static binaries ?**

Static binaries hermetically contain libraries that they are using. Dynamic binaries rely on libraries located elsewhere on the system, the binary only containing the adress of the library.
There are multiple pro and cons of **static vs dynamic**.

For `kid`, we provide a set a tool to build static binaries, as we want to ensure that:

* Binaries and dependencies are consistent accross the validation set.
* Build result is reproducible and can be verified by every user.

Using static, verified, binaries ensures that all nodes mainteners are running the same version of dependencies, the `cosmwasm` particulary.
You can see this as a protection against unexpected consensus failures due to binary dependency mismatch.

Static binaries integrity can be checked by comparing sha256sum.

#### **Requirements**

To build a static binary, we rely on `Docker` and `alpine` docker images.

##### **Install docker**

To install docker, follow [the official procedure for your platform](https://docs.docker.com/get-docker/)

##### **Install Qemu (Optional)**

If you want to build `kid` to run on a platform different from your build platform, you will need to install `Qemu`:

For linux users:

```bash
sudo apt-get install qemu binfmt-support qemu-user-static 
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

For macOS users, `Qemu` should already be installed and configured when installing `Docker Desktop`.

##### **Build**

```bash
cd ki-tools
```

Build an `amd64` static binary

```bash
make build-reproducible-amd64           # For mainnet
make build-reproducible-testnet-amd64   # For testnet
```

Build an `arm64` static binary

```bash
make build-reproducible-arm64           # For mainnet
make build-reproducible-testnet-arm64   # For testnet
```

**Note:** arm64 compatiblity is proposed but not guaranteed. We recommend users to run on amd64 platforms.

Built binaries can then be found in the **build** folder

```bash
$ tree build
build
├── Mainnet
│   └── linux
│       ├── amd64
│       │   └── kid
│       └── arm64
│           └── kid
└── Testnet
    └── linux
        ├── amd64
        │   └── kid
        └── arm64
            └── kid
```

## Disclaimer

The `ki-tools` is a modified clone of the `gaia` project. More about the latter can be found [here](https://github.com/cosmos/gaia).
