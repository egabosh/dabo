const urlParams = new URLSearchParams(window.location.search);
const symbol = urlParams.get('symbol');
const time = urlParams.get('time');
const symbol2 = urlParams.get('symbol2');

const heightrsimacdchart = 100

function timeToLocal(originalTime) {
  const d = new Date(originalTime * 1000);
  return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds()) / 1000;
}

function parseCSV(data) {
  const rows = data.split("\n");
  const result = [];
  let start = Math.max(rows.length - 1000, 0);
  let lastElements = rows.slice(start)
  for (let i = start; i < rows.length; i++) {
    const cols = rows[i].split(",");
    if (cols.length >= 23 && cols.every(element => element !== undefined && element !== null)) { // check for existing lines
      // parse the date so seconds since 1970
      cols[0] = Date.parse(cols[0])/1000,result.push(cols);
      cols[0] = timeToLocal(cols[0]);
      // coloring for MACD-Histogram
      if (cols[20] < 0) {
        cols[100] = "orange";
        if (cols[23] > 20) {
          cols[100] = "red";
        }
      }
      else {
        cols[100] = "lightgreen";
        if (cols[23] > 20) {
          cols[100] = "green";
        }
      }
    }
    else {
      console.log("invalid line on linenr " + i + ": " +rows[i]);
    }
  }
  return result;
}

function getCrosshairDataPoint(series, param) {
  if (!param.time) {
    return null;
  }
  const dataPoint = param.seriesData.get(series);
  return dataPoint || null;
}

function syncCrosshair(chart, series, dataPoint) {
  if (dataPoint) {
    chart.setCrosshairPosition(dataPoint.value, dataPoint.time, series);
    return;
  }
  chart.clearCrosshairPosition();
}

// Create the Lightweight Chart within the container element
const chart = LightweightCharts.createChart(document.getElementById('container'),
{
  rightPriceScale: {
    minimumWidth: 100,
    borderVisible: false
  },

  height: 500,

  crosshair: {
     mode: 0,
  },

  timeScale: {
    timeVisible: true,
    secondsVisible: false,
  },
  
  layout: {
    background: {
      type: 'solid',
      color: '#222',
    },
    textColor: '#DDD',
  },

  grid: {
    vertLines: { color: '#444' },
    horzLines: { color: '#444' },
  },

});

chart.applyOptions({
  watermark: {
    visible: true,
    fontSize: 18,
    horzAlign: 'top',
    vertAlign: 'left',
    color: '#DDD',
    text: symbol + " " + time,
  }
});

// define chart
const candleSeries = chart.addCandlestickSeries({upColor: 'green',  wickUpColor: 'green',  downColor: 'red', wickDownColor: 'red', borderVisible: false,});
const lineSeriesEMA12 = chart.addLineSeries({ color: 'red', lineWidth: 1, priceLineVisible: false, title: 'EMA12'});
const lineSeriesEMA26 = chart.addLineSeries({ color: 'pink', lineWidth: 1, lineStyle: 2, priceLineVisible: false, title: 'EMA26'});
const lineSeriesEMA50 = chart.addLineSeries({ color: 'cyan', lineWidth: 1, priceLineVisible: false, title: 'EMA50'});
const lineSeriesEMA100 = chart.addLineSeries({ color: 'yellow', lineWidth: 1, priceLineVisible: false, title: 'EMA100'});
const lineSeriesEMA200 = chart.addLineSeries({ color: 'white', lineWidth: 1, priceLineVisible: false, title: 'EMA200'});
const lineSeriesEMA400 = chart.addLineSeries({ color: 'orange', lineWidth: 1, priceLineVisible: false, title: 'EMA400'});
const lineSeriesEMA800 = chart.addLineSeries({ color: 'purple', lineWidth: 1, priceLineVisible: false, title: 'EMA800'});

// RSI Chart
const chartrsi = LightweightCharts.createChart(document.getElementById("container"),
{
  rightPriceScale: {
    minimumWidth: 100,
    borderVisible: false
  },
  height: heightrsimacdchart,
  
  timeScale: {
      visible: false,
  },

  layout: {
    background: {
      type: 'solid',
      color: '#222',
    },
    textColor: '#DDD',
  },

  grid: {
    vertLines: { color: '#444' },
    horzLines: { color: '#444' },
  },
});

chartrsi.applyOptions({
  watermark: {
    visible: true,
    fontSize: 18,
    horzAlign: 'top',
    vertAlign: 'left',
    color: '#DDD',
    text: 'RSI 5,14,21',
  }
});

const lineSeriesRSI5 = chartrsi.addLineSeries({ color: 'orange', lineWidth: 1, lineStyle: 2, priceLineVisible: false, title: 'RSI5'});
const lineSeriesRSI14 = chartrsi.addLineSeries({ color: 'yellow', lineWidth: 2, priceLineVisible: false, title: 'RSI14'});
const lineSeriesRSI21 = chartrsi.addLineSeries({ color: 'lightgreen', lineWidth: 1, lineStyle: 2, priceLineVisible: false, title: 'RSI21'});

// MACD Chart
const chartmacd = LightweightCharts.createChart(document.getElementById("container"),
{
  rightPriceScale: {
    minimumWidth: 100,
    borderVisible: false
  },

  height: heightrsimacdchart,
  timeScale: {
    timeVisible: true,
    secondsVisible: false,
  },

  layout: {
    background: {
      type: 'solid',
       color: '#222',
    },
    textColor: '#DDD',
  },

  grid: {
    vertLines: { color: '#444' },
    horzLines: { color: '#444' },
  },
});

chartmacd.applyOptions({
  watermark: {
    visible: true,
    fontSize: 18,
    horzAlign: 'top',
    vertAlign: 'left',
    color: '#DDD',
    text: 'MACD 12 26',
  }
});

const lineSeriesMACD = chartmacd.addLineSeries({ color: 'blue', lineWidth: 1, lineStyle: 0, priceLineVisible: false, title: 'MACD'});
const lineSeriesMACDSignal = chartmacd.addLineSeries({ color: 'orange', lineWidth: 1, lineStyle: 0, priceLineVisible: false, title: 'Signal'});
const histogramSeriesMACD = chartmacd.addHistogramSeries({ 
  priceFormat: {
   type: 'volume',
   color: 'orange',
  },
  priceLineVisible: false,
});


fetch("/botdata/asset-histories/" + symbol + ".history." + time + ".csv", { cache: 'no-store' })
.then(response => response.text())
.then(data => {
  const parsedData = parseCSV(data);

  // OHLC Data
  const bars = parsedData.map(item => ({
    time: item[0],
    open: item[1],
    high: item[2],
    low: item[3],
    close: item[4]
  }));
  candleSeries.setData(bars);

  // EMA Data
  candleSeries.setData(bars);
  const lineSeriesEMA12Data = parsedData.map(item => ({
    time: item[0],
    value: item[8]
  }));
  lineSeriesEMA12.setData(lineSeriesEMA12Data);

  const lineSeriesEMA26Data = parsedData.map(item => ({
    time: item[0],
    value: item[9]
  }));
  lineSeriesEMA26.setData(lineSeriesEMA26Data);

  const lineSeriesEMA50Data = parsedData.map(item => ({
    time: item[0],
    value: item[10]
  }));
  lineSeriesEMA50.setData(lineSeriesEMA50Data);

  const lineSeriesEMA100Data = parsedData.map(item => ({
    time: item[0],
    value: item[11]
  }));
  lineSeriesEMA100.setData(lineSeriesEMA100Data);

  const lineSeriesEMA200Data = parsedData.map(item => ({
    time: item[0],
    value: item[12]
  }));
  lineSeriesEMA200.setData(lineSeriesEMA200Data);

  const lineSeriesEMA400Data = parsedData.map(item => ({
    time: item[0],
    value: item[13]
  }));
  lineSeriesEMA400.setData(lineSeriesEMA400Data);

  const lineSeriesEMA800Data = parsedData.map(item => ({
    time: item[0],
    value: item[14]
  }));
  lineSeriesEMA800.setData(lineSeriesEMA800Data);
  
  // RSI Data
  const lineSeriesRSI5Data = parsedData.map(item => ({
    time: item[0],
    value: item[15]
  }));
  lineSeriesRSI5.setData(lineSeriesRSI5Data);

  const lineSeriesRSI14Data = parsedData.map(item => ({
    time: item[0],
    value: item[16]
  }));
  lineSeriesRSI14.setData(lineSeriesRSI14Data);

  const lineSeriesRSI21Data = parsedData.map(item => ({
    time: item[0],
    value: item[17]
  }));
  lineSeriesRSI21.setData(lineSeriesRSI21Data);

  // MACD Data
  const lineSeriesMACDData = parsedData.map(item => ({
    time: item[0],
    value: item[18]
  }));
  lineSeriesMACD.setData(lineSeriesMACDData);

  const lineSeriesMACDSignalData = parsedData.map(item => ({
    time: item[0],
    value: item[19]
  }));
  lineSeriesMACDSignal.setData(lineSeriesMACDSignalData);

  const histogramSeriesMACDData = parsedData.map(item => ({
    time: item[0],
    value: item[20],
    color: item[100]
  }));
  histogramSeriesMACD.setData(histogramSeriesMACDData);
});


// Lines for price levels
fetch("/botdata/asset-histories/" + symbol + ".history." + time + ".csv.levels", { cache: 'no-store' })
.then(response => response.text())
.then(text => {
  const levels = text.split(' ');
  levels.forEach(function(level) {
    candleSeries.createPriceLine({price: level, color: "blue", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: true, title: 'Level'});
  });
});

// Lines for RSIs
lineSeriesRSI14.createPriceLine({price: 45, color: "green", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false});
lineSeriesRSI14.createPriceLine({price: 50, color: "lightyellow", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false});
lineSeriesRSI14.createPriceLine({price: 55, color: "red", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false});


// DXY //
const DXYchart = LightweightCharts.createChart(document.getElementById('container'),
{
  rightPriceScale: {
    minimumWidth: 100,
    borderVisible: false
  },

  height: 500,

  crosshair: {
     mode: 0,
  },

  timeScale: {
    timeVisible: true,
    secondsVisible: false,
  },

  layout: {
    background: {
      type: 'solid',
      color: '#222',
    },
  textColor: '#DDD',
  },

  grid: {
    vertLines: { color: '#444' },
    horzLines: { color: '#444' },
  },

});

DXYchart.applyOptions({
  watermark: {
    visible: true,
    fontSize: 18,
    horzAlign: 'top',
    vertAlign: 'left',
    color: '#DDD',
    text: symbol2 + " " + time,
  }
});

// define DXY chart
const DXYcandleSeries = DXYchart.addCandlestickSeries({upColor: 'green',  wickUpColor: 'green',  downColor: 'red', wickDownColor: 'red', borderVisible: false,});
const DXYlineSeriesEMA200 = DXYchart.addLineSeries({ color: 'white', lineWidth: 1, priceLineVisible: false, title: 'EMA200'});
const DXYlineSeriesEMA800 = DXYchart.addLineSeries({ color: 'purple', lineWidth: 1, priceLineVisible: false, title: 'EMA800'});
const DXYlineSeriesEMA50 = DXYchart.addLineSeries({ color: 'cyan', lineWidth: 1, priceLineVisible: false, title: 'EMA50'});


// DXY RSI Chart
const DXYchartrsi = LightweightCharts.createChart(document.getElementById("container"),
{
  rightPriceScale: {
    minimumWidth: 100,
    borderVisible: false
  },
  height: heightrsimacdchart,

  timeScale: {
      visible: false,
  },

  layout: {
    background: {
      type: 'solid',
      color: '#222',
    },
    textColor: '#DDD',
  },

  grid: {
    vertLines: { color: '#444' },
    horzLines: { color: '#444' },
  },
});

DXYchartrsi.applyOptions({
  watermark: {
    visible: true,
    fontSize: 18,
    horzAlign: 'top',
    vertAlign: 'left',
    color: '#DDD',
    text: 'DXY RSI 5,14,21',
  }
});

const DXYlineSeriesRSI5 = DXYchartrsi.addLineSeries({ color: 'orange', lineWidth: 1, lineStyle: 2, priceLineVisible: false, title: 'RSI5'});
const DXYlineSeriesRSI14 = DXYchartrsi.addLineSeries({ color: 'yellow', lineWidth: 2, priceLineVisible: false, title: 'RSI14'});
const DXYlineSeriesRSI21 = DXYchartrsi.addLineSeries({ color: 'lightgreen', lineWidth: 1, lineStyle: 2, priceLineVisible: false, title: 'RSI21'});

fetch("/botdata/asset-histories/" + symbol2 + ".history." + time + ".csv", { cache: 'no-store' })
.then(response => response.text())
.then(data => {
  const DYXparsedData = parseCSV(data);

  // OHLC Data
  const DXYbars = DYXparsedData.map(item => ({
    time: item[0],
    open: item[1],
    high: item[2],
    low: item[3],
    close: item[4]
  }));
  DXYcandleSeries.setData(DXYbars);

  const DXYlineSeriesEMA50Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[10]
  }));
  DXYlineSeriesEMA50.setData(DXYlineSeriesEMA50Data);

  const DXYlineSeriesEMA200Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[12]
  }));
  DXYlineSeriesEMA200.setData(DXYlineSeriesEMA200Data);

  const DXYlineSeriesEMA800Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[14]
  }));
  DXYlineSeriesEMA800.setData(DXYlineSeriesEMA800Data);

  // RSI Data
  const DXYlineSeriesRSI5Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[15]
  }));
  DXYlineSeriesRSI5.setData(DXYlineSeriesRSI5Data);

  const DXYlineSeriesRSI14Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[16]
  }));
  DXYlineSeriesRSI14.setData(DXYlineSeriesRSI14Data);

  const DXYlineSeriesRSI21Data = DYXparsedData.map(item => ({
    time: item[0],
    value: item[17]
  }));
  DXYlineSeriesRSI21.setData(DXYlineSeriesRSI21Data);
});


// Sync charts timeScale
chart.timeScale().fitContent();
chart.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chartrsi.timeScale().setVisibleLogicalRange(timeRange);
  chartmacd.timeScale().setVisibleLogicalRange(timeRange);
  DXYchartrsi.timeScale().setVisibleLogicalRange(timeRange);
  DXYchart.timeScale().setVisibleLogicalRange(timeRange);
});

chartrsi.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chart.timeScale().setVisibleLogicalRange(timeRange);
});

chartmacd.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chart.timeScale().setVisibleLogicalRange(timeRange);
});

DXYchart.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chart.timeScale().setVisibleLogicalRange(timeRange);
});

DXYchartrsi.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
  chart.timeScale().setVisibleLogicalRange(timeRange);
});




chart.subscribeCrosshairMove(param => {
  const dataPoint = getCrosshairDataPoint(lineSeriesEMA50, param);
  syncCrosshair(chartrsi, lineSeriesRSI14, dataPoint);

  const dataPointmacd = getCrosshairDataPoint(lineSeriesEMA50, param);
  syncCrosshair(chartmacd, lineSeriesMACD, dataPointmacd);

  const DXYdataPoint = getCrosshairDataPoint(lineSeriesEMA50, param);
  syncCrosshair(DXYchart, DXYlineSeriesEMA50, DXYdataPoint);
});

chartrsi.subscribeCrosshairMove(param => {
  const dataPoint = getCrosshairDataPoint(lineSeriesRSI14, param);
  syncCrosshair(chart, lineSeriesEMA50, dataPoint);

  const dataPointmacd = getCrosshairDataPoint(lineSeriesRSI14, param);
  syncCrosshair(chartmacd, lineSeriesMACD, dataPointmacd);

  const DXYdataPoint = getCrosshairDataPoint(lineSeriesRSI14, param);
  syncCrosshair(DXYchart, DXYlineSeriesEMA50, DXYdataPoint);
});

chartmacd.subscribeCrosshairMove(param => {
  const dataPoint = getCrosshairDataPoint(lineSeriesMACD, param);
  syncCrosshair(chart, lineSeriesEMA50, dataPoint);

  const dataPointrsi = getCrosshairDataPoint(lineSeriesMACD, param);
  syncCrosshair(chartrsi, lineSeriesRSI14, dataPointrsi);

  const DXYdataPoint = getCrosshairDataPoint(lineSeriesMACD, param);
  syncCrosshair(DXYchart, DXYlineSeriesEMA50, DXYdataPoint);
});

DXYchart.subscribeCrosshairMove(param => {
  const dataPoint = getCrosshairDataPoint(DXYlineSeriesEMA50, param);
  syncCrosshair(chart, lineSeriesEMA50, dataPoint);

  const dataPointrsi = getCrosshairDataPoint(DXYlineSeriesEMA50, param);
  syncCrosshair(chartrsi, lineSeriesRSI14, dataPointrsi);

  const dataPointmacd = getCrosshairDataPoint(DXYlineSeriesEMA50, param);
  syncCrosshair(chartmacd, lineSeriesMACD, dataPointrsi);
});
