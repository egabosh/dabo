/**
 * Data Chart - TradingView Lightweight Charts Implementation
 * 
 * Displays interactive candlestick charts with:
 *   - Main price chart with EMA overlays
 *   - RSI indicator chart
 *   - MACD indicator chart
 *   - Price levels (range, fibonacci, liquidity)
 *   - Synchronized crosshair across all charts
 * 
 * URL Parameters:
 *   - file: Symbol file name (e.g., BTCUSDT.history.1d.csv)
 */

(function() {
    'use strict';

    // =========================================================================
    // URL Parameter Parsing
    // =========================================================================

    const urlParams = new URLSearchParams(window.location.search);
    const fileParam = urlParams.get('file');

    let symbol, timeframe;
    if (fileParam) {
        const parts = fileParam.split('.history.');
        if (parts.length === 2) {
            symbol = parts[0];
            timeframe = parts[1].replace('.csv', '');
        }
    }

    if (!symbol || !timeframe) {
        console.error('Invalid file parameter:', fileParam);
        document.getElementById('container').innerHTML = 
            '<div class="p-4 text-white"><h4>Error</h4><p>Invalid file parameter</p></div>';
        return;
    }

    // =========================================================================
    // Utility Functions
    // =========================================================================

    /**
     * Convert UTC timestamp to local timezone
     */
    function timeToLocal(originalTime) {
        const d = new Date(originalTime * 1000);
        return Date.UTC(
            d.getFullYear(), d.getMonth(), d.getDate(),
            d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds()
        ) / 1000;
    }

    /**
     * Parse CSV data into chart-ready format
     * Expects columns: timestamp, open, high, low, close, volume, indicators...
     */
    function parseCSV(data) {
        const rows = data.split("\n");
        const result = [];
        const start = rows.length > 433 ? rows.length - 433 : 0;
        
        for (let i = start; i < rows.length; i++) {
            const cols = rows[i].split(",");
            if (cols.length < 5) continue;

            const timestamp = Date.parse(cols[0]);
            if (isNaN(timestamp)) continue;

            const open = parseFloat(cols[1]);
            const high = parseFloat(cols[2]);
            const low = parseFloat(cols[3]);
            const close = parseFloat(cols[4]);

            // Skip rows with no OHLC data
            if (isNaN(open) && isNaN(high) && isNaN(low) && isNaN(close)) continue;

            cols[0] = timeToLocal(timestamp / 1000);

            // MACD histogram color based on direction and strength
            const macdHist = parseFloat(cols[20]) || 0;
            const strength = parseFloat(cols[23]) || 0;
            if (macdHist < 0) {
                cols[100] = strength > 20 ? "red" : "orange";
            } else {
                cols[100] = strength > 20 ? "green" : "lightgreen";
            }
            
            result.push(cols);
        }
        return result;
    }

    /**
     * Get crosshair data point from series
     */
    function getCrosshairDataPoint(series, param) {
        if (!param.time) return null;
        return param.seriesData.get(series) || null;
    }

    /**
     * Sync crosshair position between charts
     */
    function syncCrosshair(chart, series, dataPoint) {
        if (dataPoint) {
            chart.setCrosshairPosition(dataPoint.value, dataPoint.time, series);
        } else {
            chart.clearCrosshairPosition();
        }
    }

    // =========================================================================
    // Chart Configuration
    // =========================================================================

    const INDICATOR_HEIGHT = 100;
    const container = document.getElementById('container');

    const chartOptions = {
        rightPriceScale: { minimumWidth: 100, borderVisible: false },
        crosshair: { mode: 0 },
        timeScale: { timeVisible: true, secondsVisible: false },
        layout: { background: { type: 'solid', color: '#222' }, textColor: '#DDD' },
        grid: { vertLines: { color: '#444' }, horzLines: { color: '#444' } },
    };

    // =========================================================================
    // Create Charts
    // =========================================================================

    // Main candlestick chart
    const chart = LightweightCharts.createChart(container, {
        ...chartOptions,
        height: 500,
    });
    chart.applyOptions({
        watermark: {
            visible: true, fontSize: 18, horzAlign: 'left', vertAlign: 'top',
            color: '#DDD', text: symbol + " " + timeframe,
        }
    });

    // RSI chart
    const chartRSI = LightweightCharts.createChart(container, {
        ...chartOptions,
        height: INDICATOR_HEIGHT,
        timeScale: { visible: false },
    });
    chartRSI.applyOptions({
        watermark: { visible: true, fontSize: 18, horzAlign: 'left', vertAlign: 'top', color: '#DDD', text: 'RSI' }
    });

    // MACD chart
    const chartMACD = LightweightCharts.createChart(container, {
        ...chartOptions,
        height: INDICATOR_HEIGHT,
        timeScale: { timeVisible: true, secondsVisible: false },
    });
    chartMACD.applyOptions({
        watermark: { visible: true, fontSize: 18, horzAlign: 'left', vertAlign: 'top', color: '#DDD', text: 'MACD' }
    });

    // =========================================================================
    // Series Definitions
    // =========================================================================

    // Candlestick series
    const candleSeries = chart.addSeries(LightweightCharts.CandlestickSeries, {
        upColor: 'green', wickUpColor: 'green', downColor: 'red', wickDownColor: 'red', borderVisible: false,
    });

    // EMA series (various periods)
    const emaSeries = {
        ema12:  chart.addSeries(LightweightCharts.LineSeries, { color: 'red', lineWidth: 1, priceLineVisible: false }),
        ema26:  chart.addSeries(LightweightCharts.LineSeries, { color: 'pink', lineWidth: 1, lineStyle: 2, priceLineVisible: false }),
        ema50:  chart.addSeries(LightweightCharts.LineSeries, { color: 'cyan', lineWidth: 1, priceLineVisible: false }),
        ema100: chart.addSeries(LightweightCharts.LineSeries, { color: 'yellow', lineWidth: 1, priceLineVisible: false }),
        ema200: chart.addSeries(LightweightCharts.LineSeries, { color: 'white', lineWidth: 1, priceLineVisible: false }),
        ema400: chart.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, priceLineVisible: false }),
        ema800: chart.addSeries(LightweightCharts.LineSeries, { color: 'purple', lineWidth: 1, priceLineVisible: false }),
    };

    // RSI series
    const rsiSeries = {
        rsi5:  chartRSI.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, lineStyle: 2, priceLineVisible: false }),
        rsi14: chartRSI.addSeries(LightweightCharts.LineSeries, { color: 'yellow', lineWidth: 2, priceLineVisible: false }),
        rsi21: chartRSI.addSeries(LightweightCharts.LineSeries, { color: 'lightgreen', lineWidth: 1, lineStyle: 2, priceLineVisible: false }),
    };

    // MACD series
    const macdSeries = {
        macd:    chartMACD.addSeries(LightweightCharts.LineSeries, { color: 'blue', lineWidth: 1, priceLineVisible: false }),
        signal:  chartMACD.addSeries(LightweightCharts.LineSeries, { color: 'orange', lineWidth: 1, priceLineVisible: false }),
        histogram: chartMACD.addSeries(LightweightCharts.HistogramSeries, { priceFormat: { type: 'volume' }, priceLineVisible: false }),
    };

    // =========================================================================
    // Load Main Data
    // =========================================================================

    fetch(`/botdata/asset-histories/${symbol}.history.${timeframe}.csv`, { cache: 'no-store' })
        .then(r => r.text())
        .then(text => {
            const parsedData = parseCSV(text);

            // Candlestick data
            candleSeries.setData(parsedData.map(item => ({
                time: item[0],
                open: Number(item[1]),
                high: Number(item[2]),
                low: Number(item[3]),
                close: Number(item[4])
            })));

            // EMA data (columns 8-14)
            emaSeries.ema12.setData(parsedData.map(i => ({ time: i[0], value: Number(i[8]) })));
            emaSeries.ema26.setData(parsedData.map(i => ({ time: i[0], value: Number(i[9]) })));
            emaSeries.ema50.setData(parsedData.map(i => ({ time: i[0], value: Number(i[10]) })));
            emaSeries.ema100.setData(parsedData.map(i => ({ time: i[0], value: Number(i[11]) })));
            emaSeries.ema200.setData(parsedData.map(i => ({ time: i[0], value: Number(i[12]) })));
            emaSeries.ema400.setData(parsedData.map(i => ({ time: i[0], value: Number(i[13]) })));
            emaSeries.ema800.setData(parsedData.map(i => ({ time: i[0], value: Number(i[14]) })));

            // RSI data (columns 15-17)
            rsiSeries.rsi5.setData(parsedData.map(i => ({ time: i[0], value: Number(i[15]) })));
            rsiSeries.rsi14.setData(parsedData.map(i => ({ time: i[0], value: Number(i[16]) })));
            rsiSeries.rsi21.setData(parsedData.map(i => ({ time: i[0], value: Number(i[17]) })));

            // MACD data (columns 18-20)
            macdSeries.macd.setData(parsedData.map(i => ({ time: i[0], value: Number(i[18]) })));
            macdSeries.signal.setData(parsedData.map(i => ({ time: i[0], value: Number(i[19]) })));
            macdSeries.histogram.setData(parsedData.map(i => ({ time: i[0], value: Number(i[20]), color: i[100] })));

            chart.timeScale().fitContent();
        });

    // =========================================================================
    // Load Price Levels
    // =========================================================================

    // Range levels
    fetch(`/botdata/asset-histories/${symbol}.history.${timeframe}.csv.range.chart`, { cache: 'no-store' })
        .then(r => r.ok ? r.text() : "")
        .then(text => {
            if (!text) return;
            text.trim().split(/\s+/).forEach(priceStr => {
                const price = Number(priceStr);
                if (!isNaN(price)) {
                    candleSeries.createPriceLine({ price, color: "blue", lineWidth: 0.3, lineStyle: 3, axisLabelVisible: true, title: 'Range' });
                }
            });
        });

    // Fibonacci levels
    fetch(`/botdata/asset-histories/${symbol}.history.${timeframe}.csv.range.fibonacci.chart`, { cache: 'no-store' })
        .then(r => r.ok ? r.text() : "")
        .then(text => {
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

    // Liquidity levels
    const liquidityLevels = [
        { key: 'liquidity_12h', label: 'Liq.12h' },
        { key: 'liquidity_1d', label: 'Liq.1d' },
        { key: 'liquidity_3d', label: 'Liq.3d' },
        { key: 'liquidity_1w', label: 'Liq.1w' },
    ];

    liquidityLevels.forEach(level => {
        fetch(`/botdata/asset-histories/${symbol}.history.1h.${level.key}.csv.chart`, { cache: 'no-store' })
            .then(r => r.ok ? r.text() : "")
            .then(text => {
                if (!text) return;
                text.trim().split(/\s+/).map(Number).filter(n => !isNaN(n)).forEach(price => {
                    candleSeries.createPriceLine({ price, color: 'purple', lineWidth: 0.7, lineStyle: 3, axisLabelVisible: true, title: level.label });
                });
            });
    });

    // RSI level lines
    rsiSeries.rsi14.createPriceLine({ price: 45, color: "green", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });
    rsiSeries.rsi14.createPriceLine({ price: 50, color: "lightyellow", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });
    rsiSeries.rsi14.createPriceLine({ price: 55, color: "red", lineWidth: 0.5, lineStyle: 3, axisLabelVisible: false });

    // =========================================================================
    // Chart Synchronization
    // =========================================================================

    // Time scale sync
    chart.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
        chartRSI.timeScale().setVisibleLogicalRange(timeRange);
        chartMACD.timeScale().setVisibleLogicalRange(timeRange);
    });
    chartRSI.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
        chart.timeScale().setVisibleLogicalRange(timeRange);
    });
    chartMACD.timeScale().subscribeVisibleLogicalRangeChange(timeRange => {
        chart.timeScale().setVisibleLogicalRange(timeRange);
    });

    // Crosshair sync
    chart.subscribeCrosshairMove(param => {
        syncCrosshair(chartRSI, rsiSeries.rsi14, getCrosshairDataPoint(emaSeries.ema50, param));
        syncCrosshair(chartMACD, macdSeries.macd, getCrosshairDataPoint(emaSeries.ema50, param));
    });
    chartRSI.subscribeCrosshairMove(param => {
        syncCrosshair(chart, emaSeries.ema50, getCrosshairDataPoint(rsiSeries.rsi14, param));
        syncCrosshair(chartMACD, macdSeries.macd, getCrosshairDataPoint(rsiSeries.rsi14, param));
    });
    chartMACD.subscribeCrosshairMove(param => {
        syncCrosshair(chart, emaSeries.ema50, getCrosshairDataPoint(macdSeries.macd, param));
        syncCrosshair(chartRSI, rsiSeries.rsi14, getCrosshairDataPoint(macdSeries.macd, param));
    });

})();
