+++
title = "AI Agents for E-commerce with MCP: Retail Automation"
image = "images/ecommerce-ai-agents.webp"
date = 2025-06-02
description = "Build intelligent e-commerce AI agents with MCP and Gantz. Learn product recommendations, inventory optimization, and automated customer service."
draft = false
tags = ['ecommerce', 'ai', 'mcp', 'retail', 'automation', 'gantz']
voice = false
summary = "Build AI agents for e-commerce that deliver personalized product recommendations, optimize inventory levels with demand forecasting, handle customer inquiries with intent classification, recover abandoned carts with tailored incentives, and implement dynamic pricing based on competitor analysis and demand elasticity. Includes complete handler implementations and deployment instructions."

[howto]
name = "How To Build AI Agents for E-commerce with MCP"
totalTime = 40
[[howto.steps]]
name = "Understand e-commerce requirements"
text = "Learn retail automation patterns"
[[howto.steps]]
name = "Design shopping workflows"
text = "Plan customer journey automation"
[[howto.steps]]
name = "Implement recommendation tools"
text = "Build personalization features"
[[howto.steps]]
name = "Add inventory management"
text = "Create stock optimization"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy e-commerce agents using Gantz CLI"
+++

AI agents for e-commerce automate product recommendations, inventory management, customer service, and pricing optimization to drive sales and improve customer experience.

## Why Build E-commerce AI Agents?

E-commerce AI agents enable:

- **Personalization**: Individual product recommendations
- **Inventory optimization**: Smart stock management
- **Customer service**: 24/7 automated support
- **Dynamic pricing**: Market-responsive pricing
- **Cart recovery**: Automated abandonment campaigns

## E-commerce Agent Architecture

```yaml
# gantz.yaml
name: ecommerce-agent
version: 1.0.0

tools:
  recommend_products:
    description: "Recommend products to customer"
    parameters:
      customer_id:
        type: string
        required: true
      context:
        type: object
    handler: ecommerce.recommend_products

  optimize_inventory:
    description: "Optimize inventory levels"
    parameters:
      product_id:
        type: string
      category:
        type: string
    handler: ecommerce.optimize_inventory

  handle_inquiry:
    description: "Handle customer inquiry"
    parameters:
      customer_id:
        type: string
        required: true
      inquiry:
        type: string
        required: true
    handler: ecommerce.handle_inquiry

  recover_cart:
    description: "Recover abandoned cart"
    parameters:
      cart_id:
        type: string
        required: true
    handler: ecommerce.recover_cart

  dynamic_pricing:
    description: "Calculate dynamic price"
    parameters:
      product_id:
        type: string
        required: true
    handler: ecommerce.dynamic_pricing

  analyze_customer:
    description: "Analyze customer behavior"
    parameters:
      customer_id:
        type: string
        required: true
    handler: ecommerce.analyze_customer
```

## Handler Implementation

```python
# handlers/ecommerce.py
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List

STORE_API = os.environ.get('STORE_API_URL')


async def recommend_products(customer_id: str, context: dict = None) -> dict:
    """Recommend products based on customer profile and context."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get customer data
    customer = await fetch_customer(customer_id)
    browse_history = await fetch_browse_history(customer_id)
    purchase_history = await fetch_purchase_history(customer_id)
    cart = await fetch_cart(customer_id)

    # AI recommendation engine
    result = mcp.execute_tool('ai_recommend', {
        'type': 'product_recommendations',
        'customer': customer,
        'browse_history': browse_history,
        'purchase_history': purchase_history,
        'current_cart': cart,
        'context': context,
        'strategies': [
            'collaborative_filtering',
            'content_based',
            'trending',
            'frequently_bought_together',
            'personalized_deals'
        ]
    })

    recommendations = {
        'customer_id': customer_id,
        'recommendations': result.get('products', []),
        'personalized_deals': result.get('deals', []),
        'cross_sell': result.get('cross_sell', []),
        'upsell': result.get('upsell', []),
        'reasoning': result.get('reasoning'),
        'generated_at': datetime.now().isoformat()
    }

    return recommendations


async def optimize_inventory(product_id: str = None, category: str = None) -> dict:
    """Optimize inventory levels using AI."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get inventory data
    if product_id:
        products = [await fetch_product(product_id)]
    elif category:
        products = await fetch_products_by_category(category)
    else:
        products = await fetch_all_products()

    inventory_data = await fetch_inventory_levels(products)
    sales_history = await fetch_sales_history(products)
    supplier_data = await fetch_supplier_info(products)

    # AI inventory optimization
    result = mcp.execute_tool('ai_optimize', {
        'type': 'inventory_optimization',
        'products': products,
        'inventory': inventory_data,
        'sales_history': sales_history,
        'suppliers': supplier_data,
        'optimize': [
            'reorder_points',
            'safety_stock',
            'demand_forecast',
            'lead_time',
            'seasonality'
        ]
    })

    recommendations = []
    for product in result.get('recommendations', []):
        recommendations.append({
            'product_id': product['id'],
            'current_stock': product['current'],
            'recommended_stock': product['recommended'],
            'reorder_point': product['reorder_point'],
            'reorder_quantity': product['reorder_qty'],
            'forecast_demand': product['forecast'],
            'action': product['action']
        })

    # Trigger reorders if needed
    urgent_reorders = [r for r in recommendations if r['action'] == 'urgent_reorder']
    for reorder in urgent_reorders:
        await create_purchase_order(reorder)

    return {
        'products_analyzed': len(products),
        'recommendations': recommendations,
        'urgent_reorders': len(urgent_reorders),
        'potential_stockouts': result.get('stockout_risk', []),
        'overstock_alerts': result.get('overstock', [])
    }


async def handle_inquiry(customer_id: str, inquiry: str) -> dict:
    """Handle customer inquiry with AI."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get customer context
    customer = await fetch_customer(customer_id)
    orders = await fetch_recent_orders(customer_id)
    tickets = await fetch_support_history(customer_id)

    # AI inquiry handling
    result = mcp.execute_tool('ai_respond', {
        'type': 'customer_inquiry',
        'inquiry': inquiry,
        'customer': customer,
        'recent_orders': orders,
        'support_history': tickets,
        'handle': [
            'intent_classification',
            'order_lookup',
            'product_info',
            'return_processing',
            'complaint_resolution'
        ]
    })

    intent = result.get('intent')

    # Execute specific actions based on intent
    if intent == 'order_status':
        order_info = await get_order_status(result.get('order_id'))
        response = result.get('response').format(**order_info)
    elif intent == 'return_request':
        return_info = await initiate_return(result.get('order_id'), result.get('items'))
        response = result.get('response').format(**return_info)
    elif intent == 'product_question':
        response = result.get('response')
    else:
        response = result.get('response')

    # Check if escalation needed
    if result.get('escalate'):
        await escalate_to_human(customer_id, inquiry, result)

    return {
        'customer_id': customer_id,
        'inquiry': inquiry,
        'intent': intent,
        'response': response,
        'actions_taken': result.get('actions', []),
        'escalated': result.get('escalate', False),
        'satisfaction_prediction': result.get('satisfaction_score')
    }


async def recover_cart(cart_id: str) -> dict:
    """Recover abandoned cart with personalized approach."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get cart and customer data
    cart = await fetch_cart_by_id(cart_id)
    customer_id = cart.get('customer_id')
    customer = await fetch_customer(customer_id)
    abandonment_history = await fetch_abandonment_history(customer_id)

    # AI cart recovery strategy
    result = mcp.execute_tool('ai_generate', {
        'type': 'cart_recovery',
        'cart': cart,
        'customer': customer,
        'abandonment_history': abandonment_history,
        'generate': [
            'recovery_strategy',
            'incentive_recommendation',
            'message_content',
            'timing',
            'channel'
        ]
    })

    strategy = result.get('strategy')
    incentive = result.get('incentive')

    # Apply incentive if recommended
    if incentive.get('type') == 'discount':
        discount_code = await generate_discount(
            cart_id,
            incentive.get('amount'),
            incentive.get('expiry')
        )
        result['discount_code'] = discount_code

    # Send recovery message
    await send_recovery_message(
        customer_id,
        result.get('channel'),
        result.get('message'),
        result.get('discount_code')
    )

    return {
        'cart_id': cart_id,
        'customer_id': customer_id,
        'cart_value': cart.get('total'),
        'recovery_strategy': strategy,
        'incentive_offered': incentive,
        'message_sent': True,
        'channel': result.get('channel'),
        'predicted_recovery_rate': result.get('recovery_probability')
    }


async def dynamic_pricing(product_id: str) -> dict:
    """Calculate dynamic price for product."""
    from gantz import MCPClient
    mcp = MCPClient()

    product = await fetch_product(product_id)
    competitors = await fetch_competitor_prices(product_id)
    demand = await fetch_demand_data(product_id)
    inventory = await fetch_inventory_level(product_id)

    # AI dynamic pricing
    result = mcp.execute_tool('ai_optimize', {
        'type': 'dynamic_pricing',
        'product': product,
        'competitors': competitors,
        'demand': demand,
        'inventory': inventory,
        'optimize': [
            'profit_maximization',
            'competitive_positioning',
            'demand_elasticity',
            'inventory_clearance',
            'margin_protection'
        ]
    })

    pricing = {
        'product_id': product_id,
        'base_price': product.get('price'),
        'recommended_price': result.get('optimal_price'),
        'price_range': result.get('price_range'),
        'competitor_average': result.get('competitor_avg'),
        'demand_factor': result.get('demand_factor'),
        'inventory_factor': result.get('inventory_factor'),
        'expected_impact': result.get('expected_sales_impact'),
        'valid_until': result.get('valid_until')
    }

    # Update price if auto-pricing enabled
    if product.get('auto_pricing'):
        await update_product_price(product_id, pricing['recommended_price'])

    return pricing


async def analyze_customer(customer_id: str) -> dict:
    """Analyze customer behavior and value."""
    from gantz import MCPClient
    mcp = MCPClient()

    customer = await fetch_customer(customer_id)
    purchases = await fetch_purchase_history(customer_id)
    behavior = await fetch_behavior_data(customer_id)
    interactions = await fetch_interactions(customer_id)

    # AI customer analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'customer_analysis',
        'customer': customer,
        'purchases': purchases,
        'behavior': behavior,
        'interactions': interactions,
        'analyze': [
            'lifetime_value',
            'churn_risk',
            'segment',
            'preferences',
            'next_purchase_prediction',
            'engagement_score'
        ]
    })

    return {
        'customer_id': customer_id,
        'lifetime_value': result.get('ltv'),
        'churn_risk': result.get('churn_risk'),
        'segment': result.get('segment'),
        'preferences': result.get('preferences', {}),
        'next_purchase': result.get('next_purchase_prediction'),
        'engagement_score': result.get('engagement'),
        'recommendations': result.get('recommendations', [])
    }
```

## E-commerce Workflows

```python
# workflows/ecommerce.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def customer_journey_automation(customer_id: str) -> dict:
    """Automate customer journey touchpoints."""
    # Analyze customer
    analysis = await mcp.execute_tool('analyze_customer', {
        'customer_id': customer_id
    })

    # Generate recommendations
    recommendations = await mcp.execute_tool('recommend_products', {
        'customer_id': customer_id,
        'context': {'segment': analysis.get('segment')}
    })

    # Check for abandoned carts
    cart = await fetch_active_cart(customer_id)
    if cart and cart.get('abandoned'):
        await mcp.execute_tool('recover_cart', {
            'cart_id': cart['id']
        })

    return {
        'customer_id': customer_id,
        'segment': analysis.get('segment'),
        'recommendations_sent': len(recommendations.get('recommendations', [])),
        'cart_recovery_initiated': bool(cart and cart.get('abandoned'))
    }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize e-commerce agent
gantz init --template ecommerce-agent

# Set store API
export STORE_API_URL=your-store-api

# Deploy
gantz deploy --platform aws

# Get recommendations
gantz run recommend_products --customer-id cust123

# Optimize inventory
gantz run optimize_inventory --category electronics

# Recover cart
gantz run recover_cart --cart-id cart456
```

Build intelligent retail automation at [gantz.run](https://gantz.run).

## Related Reading

- [Inventory Agent](/post/inventory-agent/) - Stock management
- [Pricing Agent](/post/pricing-agent/) - Dynamic pricing
- [Churn Prevention Agent](/post/churn-prevention-agent/) - Customer retention

## Conclusion

AI agents for e-commerce transform online retail operations. With personalized recommendations, inventory optimization, and automated customer service, online stores can increase sales and customer satisfaction.

Start building e-commerce AI agents with Gantz today.
