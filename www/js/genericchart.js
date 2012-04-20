var chart;
var colors = Highcharts.getOptions().colors;
var pieoptions = {
		chart: {
			renderTo: 'container',
			plotBackgroundColor: null,
			plotBorderWidth: null,
			type: 'pie',
			plotShadow: false
		},
		title: {
			text: 'Browser market shares at a specific website, 2010'
		},
		tooltip: {
			formatter: function() {
				return '<b>'+ this.point.name +'</b>: '+ parseFloat(this.percentage).toFixed(2) +' %';
			}
		},
		plotOptions: {
			pie: {
				allowPointSelect: true,
				cursor: 'pointer',
				dataLabels: {
					enabled: true,
					color: '#000000',
					connectorColor: '#000000',
					formatter: function() {
						return '<b>'+ this.point.name +'</b>: '+ parseFloat(this.percentage).toFixed(2) +' %';
					}
				}
			}
		},
		series: [{
			name: 'Browser share',
			data: []
		}]
	}


function makeDonut(data,title1,title2, catnames,container){
        var colors = Highcharts.getOptions().colors;
        var categories = catnames;
        // Build the data arrays
        var browserData = [];
        var versionsData = [];
        for (var i = 0; i < data.length; i++) {
            // add browser data
            browserData.push({
                name: categories[i],
                y: data[i].y,
                color: data[i].color
            });  

            // add version data

            for (var j = 0; j < data[i].drilldown.data.length; j++) {
                var brightness = 0.2 - (j / data[i].drilldown.data.length) / 5 ;
                versionsData.push({
                    name: data[i].drilldown.categories[j],
                    y: data[i].drilldown.data[j],
                    color: Highcharts.Color(data[i].color).brighten(brightness).get()
                });
            }
        }
        
        // Create the chart
        chart = new Highcharts.Chart({
            chart: {
                renderTo: container,
                type: 'pie'
            },
            title: {
                text: title1
            },
            yAxis: {
                title: {
                    text: title2
                }
            },
            plotOptions: {
                pie: {
                    shadow: false
                }
            },
            tooltip: {
                formatter: function() {
                    return '<b>'+ this.point.name +'</b>: '+ parseFloat(this.percentage).toFixed(2) +' %';
                }
            },
            series: [{
                name: title1,
                data: browserData,
                size: '60%',
                dataLabels: {
                    formatter: function() {
                        return this.y > 5 ? this.point.name : null;
                    },
                    color: 'white',
                    distance: -30
                }
            }, {

                name: title2,
                data: versionsData,
                innerSize: '60%',
                dataLabels: {
                    formatter: function() {
                        // display only if larger than 1
                        return this.y > 1 ? '<b>'+ this.point.name +':</b> '+ parseFloat(this.percentage).toFixed(2) +'%'  : null;
                    }
                }
            }]
        });

        
}
