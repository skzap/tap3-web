<script>
  import { onMount } from 'svelte'
  import { Html5QrcodeScanner, Html5QrcodeScanType, Html5QrcodeSupportedFormats} from "html5-qrcode"
  import { Core } from '@walletconnect/core'
  import { Web3Wallet } from '@walletconnect/web3wallet'
  import { buildApprovedNamespaces, getSdkError } from '@walletconnect/utils'
  
  export let cardInfo
  export let signer

  let qrScanner
  let web3wallet
  let session
  let newTx
  let isPairing = false

  function onScanSuccess(decodedText, decodedResult) {
    qrScanner.clear()
    pair(decodedText)
  }

  function onScanFailure(error) {
    // handle scan failure, usually better to ignore and keep scanning.
    // for example:
    console.warn(`Code scan error = ${error}`);
  }

  function fromLink() {
    pair(document.getElementById("wcLink").value)
  }

  async function pair(uri) {
    if (isPairing || session)
      return
    console.log('PAIRING', uri)
    isPairing = true
    web3wallet.on('session_proposal', async proposal => {
      const approvedNamespaces = buildApprovedNamespaces({
        proposal: proposal.params,
        supportedNamespaces: {
          eip155: {
            chains: ['eip155:137'],
            methods: ['eth_sendTransaction', 'personal_sign'],
            events: ['accountsChanged', 'chainChanged'],
            accounts: [
              'eip155:137:'+cardInfo.pub.toLowerCase()
            ]
          }
        }
      })
      session = await web3wallet.approveSession({
        id: proposal.id,
        namespaces: approvedNamespaces
      })
      web3wallet.on('session_request', async tx => {
        console.log('SESSION REQUEST', tx)
        newTx = tx
      })

      console.log('SESSION OPEN', session)
      isPairing = false
    })
    await web3wallet.pair({ uri })
  }

  async function disconnectSession() {
    await web3wallet.disconnectSession({
      topic: session.topic,
      reason: getSdkError('USER_DISCONNECTED')
    })
    session = null
  }

  async function confirmTx() {
    let txInput = newTx.params.request.params[0]
    const tx = await signer.sendTransaction(txInput)
    const response = {
      id: newTx.id,
      result: tx.hash,
      jsonrpc: '2.0'
    }
    await web3wallet.respondSessionRequest({ 
      topic: session.topic,
      response: response
    })
    newTx = null
  }

  async function cancelTx() {
    const response = {
      id: newTx.id,
      jsonrpc: '2.0',
      error: {
        code: 5000,
        message: 'User rejected.'
      }
    }
    await web3wallet.respondSessionRequest({ 
      topic: session.topic,
      response: response
    })
    newTx = null
  }

  onMount(async () => {
    // init web3wallet
    const core = new Core({
      projectId: '71d4d66b28f7a00fbd864c766c793ae5'
    })

    web3wallet = await Web3Wallet.init({
      core,
      metadata: {
        name: 'Tap3 Web',
        description: 'Web Wallet for Tap3 cards',
        url: 'tap3.me',
        icons: []
      }
    })

    // init qrcode scanner
    qrScanner = new Html5QrcodeScanner("reader", {
      fps: 10,
      qrbox: {
        width: 300,
        height: 300
      },
      supportedScanTypes: [Html5QrcodeScanType.SCAN_TYPE_CAMERA],
      formatsToSupport: [Html5QrcodeSupportedFormats.QR_CODE]
    }, false);
    qrScanner.render(onScanSuccess, onScanFailure);
	})
  
</script>

<div>
  {#if isPairing}
    <h4>WAIT</h4>
  {:else}
    {#if session}
      {#if newTx}
        <h4>New Transaction</h4>
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="menuItem" on:click={confirmTx}>
          <button class="circleMenu">
            <i class="las la-check-circle"></i>
          </button>
          <br />
          Confirm
        </div>
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="menuItem" on:click={cancelTx}>
          <button class="circleMenu">
            <i class="las la-times-circle"></i>
          </button>
          <br />
          Cancel
        </div>
      {:else}
        <h4>Connected to {session.peer.metadata.name}</h4>
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="menuItem" on:click={disconnectSession}>
          <button class="circleMenu">
            <i class="las la-plug"></i>
          </button>
          <br />
          Disconnect
        </div>
      {/if}
    {:else}
      <h4>Scan QR Code</h4>
      <div id="reader" style="width:95%"></div>
      <h4>Or paste link</h4>
      <input type="text" id="wcLink">
      <button on:click={fromLink}>OK</button>
    {/if}
  {/if}
  
</div>