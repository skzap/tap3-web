<script>
  import {ethers} from "ethers"
  import QRCode from 'qrcode'
  import CryptoJS from 'crypto-js'
  import { onMount } from 'svelte'
  import { get } from 'svelte/store'
  import {payTo, history} from './stores/storage.js'
  import mixpanel from 'mixpanel-browser';
  import WalletConnect from './WalletConnect.svelte'

  initialize()

  let provider = new ethers.JsonRpcProvider("https://polygon-rpc.com")
  let signer
  let cardInfo = {}
  let csv = ''
  let csv2 = ''
  let page = 'cardInfo'
  let payAmount = ""
  let error
  let success
  let pending = false
  let isQRCode = false
  let maticPrice = null
  let catalogueUrl = 'https://api.tap3.me/catalogue/'
  let onRampUrl = 'https://global-stg.transak.com/'
  onRampUrl += '?apiKey=bfaa7c4c-7768-4de2-8239-cb134a03e764'
  onRampUrl += '&network=polygon'
  onRampUrl += '&cryptoCurrencyCode=MATIC'
  onRampUrl += '&walletAddress='

  async function initialize() {
    mixpanel.init('949cebe20ce072369654cc8d2ca1524c', {debug: true, track_pageview: true, persistence: 'localStorage'});
  }

  async function walletConnect() {
    page = 'walletConnect'
  }

  function blinkError() {
    document.body.style.backgroundColor = 'red'
    setTimeout(() => {document.body.style.backgroundColor = 'black'},1000)
    setTimeout(() => {error = ''},3500)
  }

  function base64ToHex(str) {
    const raw = atob(str);
    let result = '';
    for (let i = 0; i < raw.length; i++) {
      const hex = raw.charCodeAt(i).toString(16);
      result += (hex.length === 2 ? hex : '0' + hex);
    }
    return result.toLowerCase();
  }

  function base64_to_base10(str) {
    var order = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
    var base = order.length;
    var num = 0, r;
    while (str.length) {
        r = order.indexOf(str.charAt(0));
        str = str.substr(1);
        num *= base;
        num += r;
    }
    return num;
  }

  function base10_to_base64(num) {
    var order = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
    var base = order.length;
    var str = "", r;
    while (num) {
        r = num % base
        num -= r;
        num /= base;
        str = order.charAt(r) + str;
    }
    return str;
  }

  function newCard() {
    let id = Number(prompt('start card id?'))
    if (!id || isNaN(id))
      return
    let endId = Number(prompt('end card id?'))
    if (!endId || isNaN(endId))
      return
    let pw = prompt('card pw?')

    while (id <= endId) {
      // generate new wallet
      const wallet = ethers.Wallet.createRandom()
      let priv = CryptoJS.enc.Hex.parse(
        wallet.privateKey.replace('0x','')
      )
      let enc = CryptoJS.AES.encrypt(priv, pw).toString()
      let decrypted = CryptoJS.AES.decrypt(enc, pw)
      // let decString = decrypted.toString()
      if (wallet.privateKey.replace('0x', '') != decrypted.toString()) {
        console.log("error could not decrypt key")
        return
      }

      // pub key encoding
      let pub = CryptoJS.enc.Hex.parse(wallet.address.replace('0x',''))
      let pubBase64 = CryptoJS.enc.Base64.stringify(pub)
      

      // id format
      let idBase64 = base10_to_base64(id)

      let url = 'https://tap3.me/#'+pubBase64+':'+enc+':'+idBase64
      //console.log(url.length, url)

      csv += 'Link,'+url+',URL,,no,no,no\n'
      csv2 += id+',2024/03/20,'+pw+',p215,'+url+'\n'
      id++
    }

    

    // let pubBase81 = b81.encode(b16.decode(wallet.address.replace('0x','').toLowerCase()))
    // let privBase81 = b81.encode(b16.decode(
    //   CryptoJS.enc.Hex.stringify(CryptoJS.enc.Base64.parse(enc))
    // ))
    // let urlShort = 'https://tap3.me/#'+pubBase81+':'+privBase81+':'+id
    // console.log(urlShort.length, urlShort)
  }

  function decryptKey() {
    if (cardInfo.key)
      return cardInfo.key
    let pw = prompt("Enter password")
    let enc = cardInfo.priv
    let decrypted = CryptoJS.AES.decrypt(CryptoJS.enc.Base64.stringify(enc), pw).toString()
    if (!decrypted || decrypted == '' || decrypted.length != 64) {
      blinkError()
      error = 'Failed to decrypt'
      return
    }
    cardInfo.key = decrypted
    signer = new ethers.Wallet(cardInfo.key, provider)
    return decrypted
  }

  function pay() {
    mixpanel.track('Pay Init', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })
    payTo.set(cardInfo.pub)
    page = 'payScan'
  }

  function cancelPay() {
    mixpanel.track('Pay Cancel', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })
    page = 'cardInfo'
    payTo.set(null)
  }

  async function payFinish() {
    cardInfo.key = decryptKey()
    pending = true
    try {
      const tx = await signer.sendTransaction({
        to: get(payTo),
        value: ethers.parseUnits(payAmount, 'ether'),
      })
      pending = false
      document.body.style.backgroundColor = 'green'
      setTimeout(() => {document.body.style.backgroundColor = 'black'},1000)
      let hist = get(history)
      if (hist[cardInfo.pub]) {
        hist[cardInfo.pub].push([
          new Date().getTime(), get(payTo), payAmount
        ])
      } else {
        hist[cardInfo.pub] = [
          [
            new Date().getTime(), get(payTo), payAmount
          ]
        ]
      }
      history.set(hist)
      mixpanel.track('Pay Finish', {
        'addr': cardInfo.pub,
        'cardId': cardInfo.id
      })
    } catch (err) {
      pending = false
      error = err.code
      blinkError()
    }
  }

  async function openCard() {
    mixpanel.track('Unlock', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })
    cardInfo.key = decryptKey()

    document.getElementsByClassName("cardPic")[0].classList.add('animate__animated')
    if (cardInfo.key)
      document.getElementsByClassName("cardPic")[0].classList.add('animate__flip')
    else
      document.getElementsByClassName("cardPic")[0].classList.add('animate__headShake')
    setTimeout(() => {
      document.getElementsByClassName("cardPic")[0].classList.remove('animate__animated')
      document.getElementsByClassName("cardPic")[0].classList.remove('animate__flip')
      document.getElementsByClassName("cardPic")[0].classList.remove('animate__headShake')
    }, 1000)
  }

  function displayQRCode() {
    mixpanel.track('QRCode', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })

    isQRCode = !isQRCode
    if (isQRCode) {
      setTimeout(function() {
        QRCode.toCanvas(
          document.getElementById('qrCode'),
          cardInfo.pub,
          { toSJISFunc: QRCode.toSJIS, width: 300 },
          (err) => {if(err) console.log(err)}
        )
      }, 100)
    }
  }

  function formatCardId(number) {
    let res = ''
    if (number < 10000) {
      let zeroes = 4 - number.toString().length
      while (zeroes > 0) {
        res += '0'
        zeroes--
      }
      res += number
    } else {
      throw('card id too big')
    }
    return res
  }

  async function reloadCard() {
    if ($payTo != null) {
      page = 'payAmount'
    }

    // get last card info
    let cardInfoRaw = window.location.hash.replace('#','').split(':')
    if (cardInfoRaw.length != 3) {
      mixpanel.track('Redirect Landing', {
        'addr': cardInfo.pub,
        'cardId': cardInfo.id
      })
      window.location.replace("https://card.tap3.me")
      return
    }

    cardInfo = {
      id: base64_to_base10(cardInfoRaw[2]),
      priv: CryptoJS.enc.Base64.parse(cardInfoRaw[1])
    }
    cardInfo.pub = await ethers.getAddress('0x'+base64ToHex(cardInfoRaw[0]))


    // load balance
		cardInfo.bal = await provider.getBalance(cardInfo.pub)
    cardInfo.balance = Number(ethers.formatEther(cardInfo.bal)).toFixed(4)

    mixpanel.identify(cardInfo.id)
    mixpanel.track('Card Load', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })

    // load card design
    let res = await fetch(catalogueUrl + cardInfo.id)
    res = await res.json()
    cardInfo.css = res[0].css
    cardInfo.svg = res[0].svg
    cardInfo.model = res[0].id_model

    switch (cardInfo.model) {
      case 4:
        cardInfo.css = 'background-color: black; '+cardInfo.css
        break;

      case 5:
        cardInfo.css = 'background-color: #c7252b; '+cardInfo.css
        break;

      case 6:
        cardInfo.css = 'background-color: #006faf; '+cardInfo.css
        break;
    
      default:
        cardInfo.css = 'background-color: white; '+cardInfo.css
        break;
    }
  }

  async function loadPrice() {
    let res = await fetch("https://api.coinpaprika.com/v1/tickers/matic-polygon")
    let json = await res.json()
    maticPrice = json.quotes.USD.price
  }

  async function copyAddress() {
    navigator.clipboard.writeText(cardInfo.pub)
    document.body.style.backgroundColor = 'green'
    setTimeout(() => {document.body.style.backgroundColor = 'black'},1000)
  }

  async function openExplorer() {
    mixpanel.track('Explorer', {
      'addr': cardInfo.pub,
      'cardId': cardInfo.id
    })
    window.open("https://polygonscan.com/address/"+cardInfo.pub)
  }

  onMount(async () => {
    await reloadCard()
    window.addEventListener("hashchange", async function() {
      await reloadCard()
    })
    loadPrice()
	})
  
</script>

<main>
  
  {#if error}
    <div id="errorMessage">
      {error}
    </div>
  {/if}
  {#if cardInfo.pub}
    {#if page == 'cardInfo'}

      <div id="cardInfo">        
        {#if isQRCode}
          <canvas id="qrCode"></canvas>
        {:else}
          <!-- svelte-ignore a11y-click-events-have-key-events -->
          <!-- svelte-ignore a11y-no-static-element-interactions -->
          <div class="cardPic" style="{cardInfo.css}" on:click={openCard}>
            {#if cardInfo.svg}<svg class="cardSvg">
              <image xlink:href="./cards/{cardInfo.svg}.svg" />
            </svg>{/if}
            <div class="cardId">#{formatCardId(cardInfo.id)}</div>
            <div class="cardAddr">{cardInfo.pub.substr(0,7) + '...' + cardInfo.pub.substr(37,5)}</div>
            {#if cardInfo.balance}
              <div class="nativeBalance">
                ~{(cardInfo.balance * maticPrice).toFixed(2)} USD
                <br />
                <span>{cardInfo.balance} MATIC</span>
                {#if maticPrice && cardInfo.balance}
                  <div class="convertBalance">
                    <span></span>
                  </div>
                {/if}
              </div>
            {/if}
          </div>
        {/if}
        
        <div id="menu">
          <div id="menuMain">
            <br />
            {#if cardInfo.key}
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div class="menuItem" on:click={walletConnect}>
                <button class="circleMenu">
                  <i class="las la-camera"></i>
                </button>
                <br />
                WalletConnect
              </div>
              <table id="txHistory" style="width: 100%; padding-top: 1rem;">
                <thead>
                  <tr>
                    <td>Date</td>
                    <td>Details</td>
                    <td>Amount</td>
                  </tr>
                </thead>
                <tbody>
                  {#if $history[cardInfo.pub]}
                    {#each $history[cardInfo.pub] as tx}
                      <tr>
                        <td>{new Date(tx[0]).toISOString().split('T')[0]}</td>
                        <td>{tx[1].substr(0,7) + '...' + tx[1].substr(37,5)}</td>
                        <td style="color: red;">- {tx[2]}</td>
                      </tr>
                    {/each}
                  {/if}
                </tbody>
              </table>
            {:else}
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div class="menuItem" on:click={pay}>
                <button class="circleMenu">
                  <i class= "las la-donate" ></i>
                </button>
                <br />
                Pay
              </div>
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div class="menuItem" on:click={displayQRCode}>
                <button class="circleMenu">
                  <i class= "las la-qrcode" ></i>
                </button>
                <br />
                QR Code
              </div>
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div class="menuItem" on:click={copyAddress}>
                <button class="circleMenu">
                  <i class= "las la-copy" ></i>
                </button>
                <br />
                Copy Addr
              </div>
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div class="menuItem" on:click={openExplorer}>
                <button class="circleMenu">
                  <i class="las la-external-link-square-alt"></i>
                </button>
                <br />
                Explorer
              </div>
            {/if}

            <!-- SUPER HIDDEN DEV STUFF
            <br/><br/><button on:click={newCard}>New Card</button>
            <textarea bind:value={csv}></textarea>
            <textarea bind:value={csv2}></textarea> 
                END HIDDEN DEV STUFF -->
          </div>
        </div>
      </div>
    {/if}
    
    {#if page == 'payAmount'}
      <div id="numberInput">
        {#if pending}
          <h1>WAIT...</h1>
        {:else}
          <h2>Pay {$payTo.substr(0,7) + '...' + $payTo.substr(37,5)}</h2>
          {#if success}
            <h2 style='color: green'>Sent {payAmount} MATIC</h2>
          {:else}
            <h2>{#if payAmount}{payAmount} MATIC{:else}...{/if}</h2>
          {/if}
          <button class='numpadButton' on:click={() => {payAmount += '1'}}>1</button>
          <button class='numpadButton' on:click={() => {payAmount += '2'}}>2</button>
          <button class='numpadButton' on:click={() => {payAmount += '3'}}>3</button>
          <br /><br />
          <button class='numpadButton' on:click={() => {payAmount += '4'}}>4</button>
          <button class='numpadButton' on:click={() => {payAmount += '5'}}>5</button>
          <button class='numpadButton' on:click={() => {payAmount += '6'}}>6</button>
          <br /><br />
          <button class='numpadButton' on:click={() => {payAmount += '7'}}>7</button>
          <button class='numpadButton' on:click={() => {payAmount += '8'}}>8</button>
          <button class='numpadButton' on:click={() => {payAmount += '9'}}>9</button>
          <br /><br />
          {#if payAmount.indexOf('.') > -1}
            <button class='numpadButton' on:click={cancelPay} style="background-color: red;">X</button>
          {:else}
            <button class='numpadButton' on:click={() => {payAmount += '.'}}>.</button>
          {/if}
          <button class='numpadButton' on:click={() => {payAmount += '0'}}>0</button>
          <button class='numpadButton' on:click={payFinish} style="background-color: green;">✓</button>
        {/if}
        
        
      </div>
    {/if}

    {#if page == 'payScan'}
      <h1>Tap payment card</h1>
    {/if}

    {#if page == 'walletConnect'}
      <WalletConnect cardInfo={cardInfo} signer={signer}/>
    {/if}
  {/if}
</main>