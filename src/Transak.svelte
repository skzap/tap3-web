<script>
  export let pub
  export let buyOrSell
  export let balance

  let isStaging = false
  let apiKey = "32fac031-92ef-4b0c-b972-86e7b75861da"
  let apiKeyStaging = "bfaa7c4c-7768-4de2-8239-cb134a03e764"
  let network = "polygon"
  let cryptoCode = "MATIC"
  let endpoint = "https://global.transak.com/"
  let endPointStaging = "https://global-stg.transak.com/"
  let iframeUrl

  if (isStaging)
    iframeUrl = endPointStaging+'?apiKey='+apiKeyStaging
  else
    iframeUrl = endpoint+'?apiKey='+apiKey

  iframeUrl += '&network='+network
    +'&cryptoCurrencyCode='+cryptoCode
    +'&productsAvailed='+buyOrSell.toUpperCase()
    +'&exchangeScreenTitle='+buyOrSell+'%20Crypto'

  if (buyOrSell === 'Buy')
    iframeUrl += '&walletAddress='+pub

  if (buyOrSell === 'Sell')
    iframeUrl += '&cryptoAmount='+Math.round(100*balance-10)/100
</script>

<div style="position: relative; width: 100%; height: 90dvh; margin: auto; box-shadow: 0 0 12px blue; border-radius: 12px; overflow: hidden">
  <iframe
      id="transakIframe"
      src="{iframeUrl}"
      allow="camera;microphone;payment"
      style="height: 100%; width: 100%; border: none"
      title="Transak Widget">
  </iframe>
</div>

