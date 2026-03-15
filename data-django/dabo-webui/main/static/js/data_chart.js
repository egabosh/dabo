// URL Parameter lesen + PARSING für file=SYMBOL.history.TIME.csv
const urlParams = new URLSearchParams(window.location.search);
const fileParam = urlParams.get('file');

let symbol, time;
if (fileParam) {
    // file=MARKETDATA_ALTCOIN_SEASON_INDEX_COINMARKETCAP.history.1w.csv
    const parts = fileParam.split('.history.');
    if (parts.length === 2) {
        symbol = parts[0];                    // MARKETDATA_ALTCOIN_SEASON_INDEX_COINMARKETCAP
        time = parts[1].replace('.csv', '');  // 1w
    }
} 

if (!symbol || !time) {
    console.error('Cannot parse symbol/time from file parameter:', fileParam);
    document.getElementById('container').innerHTML = '<div class="p-4 text-white"><h4>Error</h4><p>Invalid file parameter: ' + fileParam + '</p></div>';
    throw new Error('No valid symbol/timeframe');
}

console.log('Loaded:', symbol, time); // DEBUG

const heightrsimacdchart = 100;

function timeToLocal(originalTime) {
  const d = new Date(originalTime * 1000);
  return Date.UTC(
    d.getFullYear(), d.getMonth(), d.getDate(),
    d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds()
  ) / 1000;
}

function parseCSV(data) {
  const rows = data.split("\n");
  const result = [];
  const start = rows.length > 433 ? rows.length - 433 : 0;
  for (let i = start; i < rows.length; i++) {
    const cols = rows[i].split(",");
    if (cols.length >= 23 && cols.every(el => el !== undefined && el !== null && el !== "")) {
      cols[0] = Date.parse(cols[0]) / 1000;
      cols[0] = timeToLocal(cols[0]);
      const macdHist = parseFloat(cols[20]);
      const strength = parseFloat(cols[23]);
      if (macdHist < 0) {
        cols[100] = "orange";
        if (strength > 20) cols[100] = "red";
      } else {
        cols[100] = "lightgreen";
        if (strength > 20) cols[100] = "green";
      }
      result.push(cols);
    }
  }
  return result;
}

function getCrosshairDataPoint(series, param) {
  if (!param.time) return null;
  return param.seriesData.get(series) || null;
}

function syncCrosshair(chart, series, dataPoint) {
  if (dataPoint) {
    chart.setCrosshairPosition(dataPoint.value, dataPoint.time, series);
  } else {
    chart.clearCrosshairPosition();
  }
}

const container = document.getElementById('container');

// Main price chart
const chart = LightweightCharts.createChart(container, {
  rightPriceScale: { minimumWidth: 100, borderVisible: false },
  height: 500,
  crosshair: { mode: 0 },
  timeScale: { timeVisible: true, secondsVisible: false },
  layout: { background: { type: 'solid', color: '#222' }, textColor: '#DDD' },
  grid: { vertLines: { color: '#444' }, horzLines: { color: '#444' } },
});

chart.applyOptions({
  watermark: {
    visible: true, fontSize: 18, horzAlign: 'top', vertAlign: 'left',
    color: '#DDD', text: symbol + " " + time,
  }
});

// ALLE Series mit korrekter addSeries API
const candleSeries = chart.addSeries(LightweightCharts.CandlestickSeries, {
  upColor: 'green', wickUpColor: 'green', downColor: 'red', wickDownColor: 'red', borderVisible: false,
});
const lineSeriesEMA12 = chart.addSeries(LightweightCharts.LineSeries, { color: 'red', lineWidth: 1, priceLineVisible: false });
const lineSeriesEMA26 = chart.addSeries(LightweightCharts.LineSeries, { color: 'pink', lineWidth: 1, lineStyle: 2, priceLineVisible: false });
const lineSeriesEMA50 = chart.addSeries(LightweightCharts.LineSeries, { color: 'cyan', lineWidth: 1, priceLineVisible: false });
const lineSeriesEMA100 = chart.addSeries(LightweightCharts.LineSeries, { color: 'yellow', lineWidth: 1, priceLineVisible: false });
const lineSeriesEMA200 = chart.addSeries(LightweightCharts.LineSeries, { color: 'white', lineWidth: 1, priceLineVisible: false });
const lineSeriesEMA400 = chart.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, priceLineVisible: false });
const lineSeriesEMA800 = chart.addSeries(LightweightCharts.LineSeries, { color: 'purple', lineWidth: 1, priceLineVisible: false });

// RSI chart
const chartrsi = LightweightCharts.createChart(container, {
  rightPriceScale: { minimumWidth: 100, borderVisible: false },
  height: heightrsimacdchart, timeScale: { visible: false },
  layout: { background: { type: 'solid', color: '#222' }, textColor: '#DDD' },
  grid: { vertLines: { color: '#444' }, horzLines: { color: '#444' } },
});

chartrsi.applyOptions({
  watermark: { visible: true, fontSize: 18, horzAlign: 'top', vertAlign: 'left', color: '#DDD', text: 'RSI 5,14,21' }
});

const lineSeriesRSI5 = chartrsi.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, lineStyle: 2, priceLineVisible: false });
const lineSeriesRSI14 = chartrsi.addSeries(LightweightCharts.LineSeries, { color: 'yellow', lineWidth: 2, priceLineVisible: false });
const lineSeriesRSI21 = chartrsi.addSeries(LightweightCharts.LineSeries, { color: 'lightgreen', lineWidth: 1, lineStyle: 2, priceLineVisible: false });

// MACD chart
const chartmacd = LightweightCharts.createChart(container, {
  rightPriceScale: { minimumWidth: 100, borderVisible: false },
  height: heightrsimacdchart,
  timeScale: { timeVisible: true, secondsVisible: false },
  layout: { background: { type: 'solid', color: '#222' }, textColor: '#DDD' },
  grid: { vertLines: { color: '#444' }, horzLines: { color: '#444' } },
});

chartmacd.applyOptions({
  watermark: { visible: true, fontSize: 18, horzAlign: 'top', vertAlign: 'left', color: '#DDD', text: 'MACD 12 26' }
});

const lineSeriesMACD = chartmacd.addSeries(LightweightCharts.LineSeries, { color: 'blue', lineWidth: 1, priceLineVisible: false });
const lineSeriesMACDSignal = chartmacd.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, priceLineVisible: false });
const histogramSeriesMACD = chartmacd.addSeries(LightweightCharts.HistogramSeries, { priceFormat: { type: 'volume' }, priceLineVisible: false });

// Fetch main CSV
fetch(`/botdata/asset-histories/${symbol}.history.${time}.csv`, { cache: 'no-store' })
  .then(r => r.text())
  .then(text => {
    const parsedData = parseCSV(text);
    const bars = parsedData.map(item => ({
      time: item[0], open: Number(item[1]), high: Number(item[2]), low: Number(item[3]), close: Number(item[4])
    }));
    candleSeries.setData(bars);

    lineSeriesEMA12.setData(parsedData.map(i => ({ time: i[0], value: Number(i[8]) })));
    lineSeriesEMA26.setData(parsedData.map(i => ({ time: i[0], value: Number(i[9]) })));
    lineSeriesEMA50.setData(parsedData.map(i => ({ time: i[0], value: Number(i[10]) })));
    lineSeriesEMA100.setData(parsedData.map(i => ({ time: i[0], value: Number(i[11]) })));
    lineSeriesEMA200.setData(parsedData.map(i => ({ time: i[0], value: Number(i[12]) })));
    lineSeriesEMA400.setData(parsedData.map(i => ({ time: i[0], value: Number(i[13]) })));
    lineSeriesEMA800.setData(parsedData.map(i => ({ time: i[0], value: Number(i[14]) })));

    lineSeriesRSI5.setData(parsedData.map(i => ({ time: i[0], value: Number(i[15]) })));
    lineSeriesRSI14.setData(parsedData.map(i => ({ time: i[0], value: Number(i[16]) })));
    lineSeriesRSI21.setData(parsedData.map(i => ({ time: i[0], value: Number(i[17]) })));

    lineSeriesMACD.setData(parsedData.map(i => ({ time: i[0], value: Number(i[18]) })));
    lineSeriesMACDSignal.setData(parsedData.map(i => ({ time: i[0], value: Number(i[19]) })));
    histogramSeriesMACD.setData(parsedData.map(i => ({ time: i[0], value: Number(i[20]), color: i[100] })));

    chart.timeScale().fitContent();
  });

// Price range, Fibonacci, Liquidity, RSI levels, Sync (identisch wie vorher)...
fetch(`/botdata/asset-histories/${symbol}.history.${time}.csv.range.chart`, { cache: 'no-store' })
  .then(r => r.ok ? r.text() : "").then(text => {
    if (!text) return;
    text.trim().split(/\s+/).forEach(priceStr => {
      const price = Number(priceStr);
      if (!isNaN(price)) {
        candleSeries.createPriceLine({ price, color: "blue", lineWidth: 0.3, lineStyle: 3, axisLabelVisible: true, title: 'Range' });
      }
    });
  });

fetch(`/botdata/asset-histories/${symbol}.history.${time}.csv.range.fibonacci.chart`, { cache: 'no-store' })
  .then(r => r.ok ? r.text() : "").then(text => {
    if (!text) return;
    text.trim().split('\n').forEach(line => {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) return;
      let label = parts[0], priceStr = parts[1], color = "blue";
      if (label.startsWith("up_")) { color = "lightgreen"; label = label.substring(3); }
      else if (label.startsWith("down_")) { color = "LightCoral"; label = label.substring(5); }
      if (label === "0" || label === "1") return;
      const price = parseFloat(priceStr);
      if (!isNaN(price) && price >= 0) {
        candleSeries.createPriceLine({ price, color, lineWidth: 0.3, lineStyle: 3, axisLabelVisible: true, title: label });
      }
    });
  });

const liquidityTFs = [
  { key: 'liquidity_12h', label: 'Liq. 12h', color: 'purple' },
  { key: 'liquidity_1d', label: 'Liq. 1d', color: 'purple' },
  { key: 'liquidity_3d', label: 'Liq. 3d', color: 'purple' },
  { key: 'liquidity_1w', label: 'Liq. 1w', color: 'purple' },
];

liquidityTFs.forEach(tf => {
  fetch(`/botdata/asset-histories/${symbol}.history.1h.${tf.key}.csv.chart`, { cache: 'no-store' })
    .then(r => r.ok ? r.text() : "").then(text => {
      if (!text) return;
      text.trim().split(/\s+/).map(Number).filter(n => !isNaN(n)).forEach(price => {
        candleSeries.createPriceLine({ price, color: tf.color, lineWidth: 0.7, lineStyle: 3, axisLabelVisible: true, title: tf.label });
      });
    });
});

lineSeriesRSI14.createPriceLine({ price: 45, color: "green", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });
lineSeriesRSI14.createPriceLine({ price: 50, color: "lightyellow", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });
lineSeriesRSI14.createPriceLine({ price: 55, color: "red", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });

// Sync Charts
chart.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chartrsi.timeScale().setVisibleLogicalRange(timeRange);
  chartmacd.timeScale().setVisibleLogicalRange(timeRange);
});
chartrsi.timeScale().subscribeVisibleLogicalRangeChange(timeRange => chart.timeScale().setVisibleLogicalRange(timeRange));
chartmacd.timeScale().subscribeVisibleLogicalRangeChange(timeRange => chart.timeScale().setVisibleLogicalRange(timeRange));

// Crosshair sync
chart.subscribeCrosshairMove(param => {
  syncCrosshair(chartrsi, lineSeriesRSI14, getCrosshairDataPoint(lineSeriesEMA50, param));
  syncCrosshair(chartmacd, lineSeriesMACD, getCrosshairDataPoint(lineSeriesEMA50, param));
});
chartrsi.subscribeCrosshairMove(param => {
  syncCrosshair(chart, lineSeriesEMA50, getCrosshairDataPoint(lineSeriesRSI14, param));
  syncCrosshair(chartmacd, lineSeriesMACD, getCrosshairDataPoint(lineSeriesRSI14, param));
});
chartmacd.subscribeCrosshairMove(param => {
  syncCrosshair(chart, lineSeriesEMA50, getCrosshairDataPoint(lineSeriesMACD, param));
  syncCrosshair(chartrsi, lineSeriesRSI14, getCrosshairDataPoint(lineSeriesMACD, param));
});

