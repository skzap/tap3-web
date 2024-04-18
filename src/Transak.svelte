<script>
  export let pub

  (function () {
      const transakIframe = document.getElementById("transakIframe")?.contentWindow;

      window.addEventListener('message', (message) => {
          if (message.source !== transakIframe) return;

          // To get all the events
          console.log('Event ID: ', message?.data?.event_id);
          console.log('Data: ', message?.data?.data);

          // This will trigger when the user marks payment is made
          if (message?.data?.event_id === 'TRANSAK_ORDER_SUCCESSFUL') {
              console.log('Order Data: ', message?.data?.data);
          }
      });
  })();
</script>

<div style="position: relative; width: 100%; height: 90dvh; margin: auto; box-shadow: 0 0 12px blue; border-radius: 12px; overflow: hidden">
  <iframe
      id="transakIframe"
      src="https://global-stg.transak.com/?apiKey=bfaa7c4c-7768-4de2-8239-cb134a03e764&network=polygon&cryptoCurrencyCode=MATIC&walletAddress={pub}"
      allow="camera;microphone;payment"
      style="height: 100%; width: 100%; border: none">
  </iframe>
</div>

