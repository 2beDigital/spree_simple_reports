$ ->
  if $('#sales_total').length > 0
    options =
      valueNames: [ 'name', 'sku', 'quantity', 'sales' ]

    list = new List('sales_total', options)
    list.sort('sales', { order: 'desc' })

  if $('#total_sales_by_product').length > 0
    options =
      valueNames: [ 'name', 'sku', 'slug', 'quantity', 'sales' ]

    list = new List('total_sales_by_product', options)
    list.sort('sales', { order: 'desc' })

$('#quantity').click ->
	options =
	  valueNames: [ 'name', 'sku', 'slug', 'quantity', 'sales' ]

	list = new List('total_sales_by_product', options)
	list.sort('quantity', { order: 'desc' })