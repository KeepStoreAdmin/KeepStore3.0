<%@ Page Title="Product Detail" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Product Detail
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
<!-- /Header -->
        <!-- Breakcrumbs -->
        <div class="tf-sp-1">
            <div class="container">
                <ul class="breakcrumbs">
                    <li>
                        <a href="index.html" class="body-small link">
                            Home
                        </a>
                    </li>
                    <li class="d-flex align-items-center">
                        <i class="icon icon-arrow-right"></i>
                    </li>
                    <li>
                        <a href="product-grid.html" class="body-small link">
                            Shop
                        </a>
                    </li>
                    <li class="d-flex align-items-center">
                        <i class="icon icon-arrow-right"></i>
                    </li>
                    <li>
                        <span class="body-small">Product Detail</span>
                    </li>
                </ul>
            </div>
        </div>
        <!-- /Breakcrumbs -->
        <!-- Product Main -->
        <section>
            <div class="tf-main-product section-image-zoom">
                <div class="container">

                    <div class="row">
                        <div class="col-md-6">
                            <!-- Product Image -->
                            <div class="tf-product-media-wrap thumbs-default sticky-top">
                                <div class="thumbs-slider">
                                    <div class="swiper tf-product-media-main" id="gallery-swiper-started">
                                        <div class="swiper-wrapper">
                                            <div class="swiper-slide" data-color="gray">
                                                <a href="images/product/product-detail-1.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        src="images/product/product-detail-1.jpg"
                                                        data-zoom="images/product/product-detail-1.jpg"
                                                        data-src="images/product/product-detail-1.jpg" alt="">
                                                </a>
                                            </div>
                                            <div class="swiper-slide" data-color="gray">
                                                <a href="images/product/product-detail-2.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        data-zoom="images/product/product-detail-2.jpg"
                                                        data-src="images/product/product-detail-2.jpg"
                                                        src="images/product/product-detail-2.jpg" alt="">
                                                </a>
                                            </div>
                                            <div class="swiper-slide" data-color="gray">
                                                <a href="images/product/product-detail-3.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        data-zoom="images/product/product-detail-3.jpg"
                                                        data-src="images/product/product-detail-3.jpg"
                                                        src="images/product/product-detail-3.jpg" alt="">
                                                </a>
                                            </div>
                                            <div class="swiper-slide" data-color="gray">
                                                <a href="images/product/product-detail-4.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        data-zoom="images/product/product-detail-4.jpg"
                                                        data-src="images/product/product-detail-4.jpg"
                                                        src="images/product/product-detail-4.jpg" alt="">
                                                </a>
                                            </div>
                                            <div class="swiper-slide" data-color="beige">
                                                <a href="images/product/product-detail-5.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        data-zoom="images/product/product-detail-5.jpg"
                                                        data-src="images/product/product-detail-5.jpg"
                                                        src="images/product/product-detail-5.jpg" alt="">
                                                </a>
                                            </div>
                                            <div class="swiper-slide" data-color="beige">
                                                <a href="images/product/product-detail-6.jpg" target="_blank"
                                                    class="item" data-pswp-width="600px" data-pswp-height="800px">
                                                    <img class="tf-image-zoom lazyload"
                                                        data-zoom="images/product/product-detail-6.jpg"
                                                        data-src="images/product/product-detail-6.jpg"
                                                        src="images/product/product-detail-6.jpg" alt="">
                                                </a>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="container-swiper">
                                        <div class="swiper tf-product-media-thumbs other-image-zoom"
                                            data-direction="horizontal">
                                            <div class="swiper-wrapper stagger-wrap">
                                                <div class="swiper-slide stagger-item" data-color="gray">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-1.jpg"
                                                            src="images/product/product-detail-1.jpg" alt="">
                                                    </div>
                                                </div>
                                                <div class="swiper-slide stagger-item" data-color="gray">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-2.jpg"
                                                            src="images/product/product-detail-2.jpg" alt="">
                                                    </div>
                                                </div>
                                                <div class="swiper-slide stagger-item" data-color="gray">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-3.jpg"
                                                            src="images/product/product-detail-3.jpg" alt="">
                                                    </div>
                                                </div>
                                                <div class="swiper-slide stagger-item" data-color="gray">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-4.jpg"
                                                            src="images/product/product-detail-4.jpg" alt="">
                                                    </div>
                                                </div>
                                                <div class="swiper-slide stagger-item" data-color="beige">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-5.jpg"
                                                            src="images/product/product-detail-5.jpg" alt="">
                                                    </div>
                                                </div>
                                                <div class="swiper-slide stagger-item" data-color="beige">
                                                    <div class="item">
                                                        <img class="lazyload"
                                                            data-src="images/product/product-detail-6.jpg"
                                                            src="images/product/product-detail-6.jpg" alt="">
                                                    </div>
                                                </div>
                                            </div>

                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- /Product Image -->
                        </div>
                        <div class="col-md-6">
                            <!-- Product Infor -->
                            <div class="tf-product-info-wrap position-relative">
                                <div class="tf-zoom-main"></div>
                                <div class="tf-product-info-list other-image-zoom flex-xxl-nowrap">
                                    <div class="tf-product-info-content">

                                        <div class="infor-heading">
                                            <p class="caption">Categories:
                                                <a href="shop-default.html" class="link text-secondary">
                                                    Consumer Electronics
                                                </a>
                                            </p>
                                            <h5 class="product-info-name fw-semibold">
                                                Elite Gourmet EKT1001B Electric
                                                BPA-Free Glass Kettle, Cordless 360° Base
                                            </h5>
                                            <ul class="product-info-rate-wrap">
                                                <li class="star-review">
                                                    <ul class="list-star">
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star text-main-4"></i>
                                                        </li>
                                                    </ul>
                                                    <p class="caption text-main-2">Reviews (1.738)</p>
                                                </li>
                                                <li>
                                                    <p class="caption text-main-2">Sold: 349</p>
                                                </li>
                                                <li class="d-flex">
                                                    <a href="shop-default.html" class="caption text-secondary link">View
                                                        shop</a>
                                                </li>
                                            </ul>
                                        </div>
                                        <div class="infor-center">
                                            <div class="product-info-price">
                                                <h4 class="text-primary">$18.99</h4>
                                                <span class="price-text text-main-2 old-price">$20.99</span>
                                            </div>
                                            <ul class="product-fearture-list">
                                                <li>
                                                    <p class="body-md-2 fw-semibold">Brand</p>
                                                    <span class="body-text-3">Elite Gourmet</span>
                                                </li>
                                                <li>
                                                    <p class="body-md-2 fw-semibold">Capacity</p>
                                                    <span class="body-text-3">1 Liters</span>
                                                </li>
                                                <li>
                                                    <p class="body-md-2 fw-semibold">Material</p>
                                                    <span class="body-text-3">Glass</span>
                                                </li>
                                                <li>
                                                    <p class="body-md-2 fw-semibold">Wattage</p>
                                                    <span class="body-text-3">1100 watts</span>
                                                </li>

                                            </ul>
                                        </div>
                                        <div class="infor-bottom">
                                            <h6 class="fw-semibold">About this item</h6>
                                            <ul class="product-about-list">
                                                <li>
                                                    <p class="body-text-3">
                                                        Here’s the quickest way to enjoy your delicious hot tea
                                                        every
                                                        single day.
                                                    </p>
                                                </li>
                                                <li>
                                                    <p class="body-text-3">
                                                        100% BPA - Free premium design meets excellent
                                                    </p>
                                                </li>
                                                <li>
                                                    <p class="body-text-3">
                                                        No more messy accidents or spills
                                                    </p>
                                                </li>
                                                <li>
                                                    <p class="body-text-3">
                                                        So easy & convenient that everyone can use it
                                                    </p>
                                                </li>
                                                <li>
                                                    <p class="body-text-3">
                                                        This powerful 900-1100-Watt kettle has convenient capacity
                                                        markings on the body lets you accurately
                                                    </p>
                                                </li>
                                                <li>
                                                    <p class="body-text-3">
                                                        1 year limited warranty and us-based customer support team
                                                        lets
                                                        you buy with confidence.
                                                    </p>
                                                </li>
                                            </ul>
                                        </div>
                                    </div>
                                    <div class="tf-product-info-choose-option sticky-top">
                                        <div class="product-delivery">
                                            <p class="price-text fw-medium text-primary">
                                                $18.99
                                            </p>
                                            <p>
                                                <i class="icon-delivery-2"></i>
                                                Free shipping
                                            </p>
                                            <div class="shipping-to">
                                                <p class="body-md-2">
                                                    Shipping to:
                                                </p>
                                                <div class="tf-cur">
                                                    <div class="tf-cur-item">
                                                        <select class="select-default cs-pointer fw-semibold body-md-2">
                                                            <option selected="">Metro Manila</option>
                                                            <option>Metro Manila </option>
                                                        </select>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="product-quantity">
                                            <p class=" title body-text-3">
                                                Quantity
                                            </p>
                                            <div class="wg-quantity">
                                                <button class="btn-quantity btn-decrease">
                                                    <i class="icon-minus"></i>
                                                </button>
                                                <input class="quantity-product" type="text" name="number" value="1">
                                                <button class="btn-quantity btn-increase">
                                                    <i class="icon-plus"></i>
                                                </button>
                                            </div>
                                        </div>
                                        <div class="product-color">
                                            <p class=" title body-text-3">
                                                Color
                                            </p>
                                            <div class="tf-select-color ">
                                                <select class="select-color">
                                                    <option selected="">Graphite Black</option>
                                                    <option>Graphite Blue </option>
                                                </select>
                                            </div>
                                        </div>
                                        <div class="product-box-btn">
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="tf-btn text-white">
                                                Add to cart
                                                <i class="icon-cart-2"></i>
                                            </a>
                                            <a href="shop-cart.html" class="tf-btn text-white btn-gray">
                                                Buy now
                                            </a>
                                        </div>
                                        <div class="product-detail">
                                            <p class="caption">Details</p>

                                            <p class="body-text-3">
                                                <span>
                                                    Return policy: Eligible for Return, Refund or Replacement within
                                                    30
                                                    days of receipt
                                                </span>
                                                <span>
                                                    Support: Free Amazon tech support included
                                                </span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- /Product Infor -->

                        </div>
                    </div>
                </div>
            </div>
        </section>
        <!-- /Product Main -->

        <!-- Product Description Tab -->
        <section class="tf-sp-4 ">
            <div class="container">
                <div class="flat-animate-tab flat-title-tab-product-des">
                    <div class=" flat-title-tab text-center">
                        <ul class="menu-tab-line" role="tablist">
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-usually" class="tab-link product-title fw-semibold active"
                                    data-bs-toggle="tab">Usually Bought
                                    Together</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-des" class="tab-link product-title fw-semibold"
                                    data-bs-toggle="tab">Description</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-infor" class="tab-link product-title fw-semibold"
                                    data-bs-toggle="tab">Product
                                    information</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-review" class="tab-link product-title fw-semibold"
                                    data-bs-toggle="tab">Reviews</a>
                            </li>

                        </ul>
                    </div>
                    <div class="tab-content">
                        <div class="tab-pane active show" id="prd-usually" role="tabpanel">
                            <div class="tab-main tab-usually flex-md-wrap">
                                <div class="card-usually hover-img">
                                    <a href="#" class="image img-style">
                                        <img src="images/product/usually-buy-2.jpg"
                                            data-src="images/product/usually-buy-2.jpg" alt="" class="lazyload">
                                    </a>
                                    <div class="content">
                                        <div class="checkbox-item-wrap">
                                            <label>
                                                <input type="checkbox" class="checkbox-item" checked>
                                                <span class="btn-checkbox"></span>
                                            </label>
                                        </div>
                                        <div class="box-name">
                                            <a href="#" class="prd-name body-md-2 text-main link-secondary fw-semibold">
                                                This item: Elite Gourmet EKT1001B Electric BPA-Free Glass Kettle,
                                                Cordless 360°...
                                            </a>
                                            <p class="price-text fw-medium">$18.99</p>
                                        </div>
                                    </div>
                                </div>
                                <span class="icon">
                                    <i class="icon-plus fs-28"></i>
                                </span>
                                <div class="card-usually hover-img">
                                    <a href="#" class="image img-style">
                                        <img src="images/product/usually-buy-1.jpg"
                                            data-src="images/product/usually-buy-1.jpg" alt="" class="lazyload">
                                    </a>
                                    <div class="content">
                                        <div class="checkbox-item-wrap">
                                            <label>
                                                <input type="checkbox" class="checkbox-item">
                                                <span class="btn-checkbox"></span>
                                            </label>
                                        </div>
                                        <div class="box-name">
                                            <a href="#" class="prd-name body-md-2 text-main link-secondary fw-semibold">
                                                Rubbermaid No-Slip Large, Silverware Tray Organizer, Black with Gray
                                            </a>
                                            <p class="price-text fw-medium">$8.29</p>
                                        </div>
                                    </div>
                                </div>
                                <div class="box-total-btn">
                                    <p class="body-text-3 text-center">Total price: <span
                                            class="text-primary">$27.29</span> </p>
                                    <a href="#shoppingCart" data-bs-toggle="offcanvas" class="tf-btn btn-line">
                                        Add to cart
                                        <i class="icon-cart-2"></i>
                                    </a>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane" id="prd-des" role="tabpanel">
                            <div class="tab-main tab-des">
                                <p class="body-text-3">
                                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec tristique nisi id
                                    leo
                                    mollis egestas. Ut ac ante tincidunt dolor viverra vestibulum. Fusce eget
                                    pharetra
                                    lorem. Pellentesque ac feugiat nisi. Nulla sollicitudin cursus neque, dapibus
                                    aliquet nulla congue congue. In eget sagittis metus, nec semper tortor. Etiam in
                                    nunc dui. Sed nibh ante, maximus eu commodo ac, mattis quis elit. Maecenas
                                    cursus
                                    libero et risus sollicitudin mollis. Sed ultricies sagittis sem, vel iaculis
                                    sapien
                                    dapibus non. Vivamus facilisis, diam et condimentum sagittis, lectus enim
                                    iaculis
                                    ipsum, eu finibus urna tellus sit amet ex. Aliquam eget rhoncus lorem. Duis ut
                                    metus
                                    eget sapien lobortis varius id vel arcu. Sed hendrerit, arcu eget ullamcorper
                                    efficitur, enim magna tempus erat, id pretium libero ligula vitae tortor.
                                    Aliquam
                                    vehicula eleifend sem nec maximus. Aenean ultricies ipsum et laoreet tincidunt.
                                </p>
                                <div class="image">
                                    <img src="images/product/description-1.jpg"
                                        data-src="images/product/description-1.jpg" alt="" class="lazyload">
                                </div>
                                <p class="body-text-3">
                                    Morbi interdum purus id justo pellentesque feugiat. Sed malesuada facilisis
                                    enim,
                                    volutpat ultrices nulla commodo ut. Proin pulvinar pharetra lacinia. Nulla massa
                                    massa, elementum vel gravida nec, fermentum vel risus. Cras eu ipsum id metus
                                    sollicitudin scelerisque. Maecenas libero dui, faucibus vel pharetra non,
                                    eleifend
                                    sit amet felis. Etiam metus nibh, auctor non orci in, consectetur pretium enim
                                </p>
                                <div class="image">
                                    <img src="images/product/description-2.jpg"
                                        data-src="images/product/description-2.jpg" alt="" class="lazyload">
                                </div>
                                <p class="body-text-3">
                                    Pellentesque quis efficitur leo. Maecenas accumsan est in nibh interdum, quis
                                    dignissim neque scelerisque. Ut suscipit et leo sit amet lacinia. Sed a laoreet
                                    leo,
                                    ut tristique risus. Integer a est ut est semper fermentum nec quis nunc.
                                    Phasellus
                                    aliquam neque eget quam gravida, quis venenatis turpis tristique. Mauris id
                                    congue
                                    augue. Pellentesque hendrerit porttitor purus, vel porttitor sem blandit vel. Ut
                                    auctor, nibh tempus volutpat porttitor, urna ligula gravida lacus, non mollis
                                    purus
                                    neque ac lorem. Morbi sodales convallis laoreet. Mauris efficitur convallis odio
                                    sed
                                    congue.
                                </p>
                            </div>
                        </div>
                        <div class="tab-pane" id="prd-infor" role="tabpanel">
                            <div class="tab-main tab-info">
                                <ul class="list-feature">
                                    <li>
                                        <p class="name-feature">Package Dimensions</p>
                                        <p class="property">8 x 8 x 6.7 inches</p>
                                    </li>
                                    <li>
                                        <p class="name-feature">Item Weight</p>
                                        <p class="property">2.2 pounds</p>
                                    </li>
                                    <li>
                                        <p class="name-feature">Manufacturer</p>
                                        <p class="property">Elite Gourmet</p>
                                    </li>
                                    <li>
                                        <p class="name-feature">ASIN</p>
                                        <p class="property">B09H3LWKYQ</p>
                                    </li>
                                    <li>
                                        <p class="name-feature">Country of Origin</p>
                                        <p class="property">China</p>
                                    </li>

                                    <li>
                                        <p class="name-feature">Item model number</p>
                                        <p class="property">EKT1001B</p>
                                    </li>
                                    <li>
                                        <p class="name-feature">Customer Reviews</p>
                                        <div class="w-100 star-review flex-wrap">
                                            <ul class="list-star">
                                                <li>
                                                    <i class="icon-star"></i>
                                                </li>
                                                <li>
                                                    <i class="icon-star"></i>
                                                </li>
                                                <li>
                                                    <i class="icon-star"></i>
                                                </li>
                                                <li>
                                                    <i class="icon-star"></i>
                                                </li>
                                                <li>
                                                    <i class="icon-star text-main-4"></i>
                                                </li>
                                            </ul>
                                            <p class="caption text-main-2">Reviews (1.738)</p>
                                        </div>
                                    </li>
                                    <li>
                                        <p class="name-feature">Date First Available</p>
                                        <p class="property"> September 24, 2021</p>
                                    </li>
                                </ul>
                            </div>
                        </div>
                        <div class="tab-pane" id="prd-review" role="tabpanel">
                            <div class="tab-main tab-review flex-lg-nowrap">
                                <div class="tab-rating-wrap">
                                    <div class="rating-percent">
                                        <p class="rate-percent">4.8 <span>/ 5</span></p>
                                        <ul class="list-star justify-content-center">
                                            <li>
                                                <i class="icon-star"></i>
                                            </li>
                                            <li>
                                                <i class="icon-star"></i>
                                            </li>
                                            <li>
                                                <i class="icon-star"></i>
                                            </li>
                                            <li>
                                                <i class="icon-star"></i>
                                            </li>
                                            <li>
                                                <i class="icon-star text-main-4"></i>
                                            </li>
                                        </ul>
                                        <p class="text-cl-3">
                                            Based on 1.738 reviews
                                        </p>
                                    </div>
                                    <ul class="rating-progress-list">
                                        <li>
                                            <p class="start-number body-text-3">5<i class="icon-star text-third"></i>
                                            </p>

                                            <div class="rating-progress">
                                                <div class="progress style-2" role="progressbar"
                                                    aria-label="Basic example" aria-valuenow="0" aria-valuemin="0"
                                                    aria-valuemax="100">
                                                    <div class="progress-bar" style="width: 100%;"></div>
                                                </div>
                                            </div>
                                            <p class="count-review body-text-3">100</p>
                                        </li>
                                        <li>
                                            <p class="start-number body-text-3">4<i class="icon-star text-third"></i>
                                            </p>
                                            <div class="rating-progress">
                                                <div class="progress style-2" role="progressbar"
                                                    aria-label="Basic example" aria-valuenow="0" aria-valuemin="0"
                                                    aria-valuemax="100">
                                                    <div class="progress-bar" style="width: 80%;"></div>
                                                </div>
                                            </div>
                                            <p class="count-review body-text-3">87</p>
                                        </li>
                                        <li>
                                            <p class="start-number body-text-3">3<i class="icon-star text-third"></i>
                                            </p>
                                            <div class="rating-progress">
                                                <div class="progress style-2" role="progressbar"
                                                    aria-label="Basic example" aria-valuenow="0" aria-valuemin="0"
                                                    aria-valuemax="100">
                                                    <div class="progress-bar" style="width: 60%;"></div>
                                                </div>
                                            </div>
                                            <p class="count-review body-text-3">32</p>
                                        </li>
                                        <li>
                                            <p class="start-number body-text-3">2<i class="icon-star text-third"></i>
                                            </p>
                                            <div class="rating-progress">
                                                <div class="progress style-2" role="progressbar"
                                                    aria-label="Basic example" aria-valuenow="0" aria-valuemin="0"
                                                    aria-valuemax="100">
                                                    <div class="progress-bar" style="width: 40%;"></div>
                                                </div>
                                            </div>
                                            <p class="count-review body-text-3">24</p>
                                        </li>
                                        <li>
                                            <p class="start-number body-text-3">1<i class="icon-star text-third"></i>
                                            </p>
                                            <div class="rating-progress">
                                                <div class="progress style-2" role="progressbar"
                                                    aria-label="Basic example" aria-valuenow="0" aria-valuemin="0"
                                                    aria-valuemax="100">
                                                    <div class="progress-bar" style="width: 0%;"></div>
                                                </div>
                                            </div>
                                            <p class="count-review body-text-3">0</p>
                                        </li>
                                    </ul>
                                    <div class="rating-filter-wrap">
                                        <p class="title-sidebar fw-bold">Filter by</p>
                                        <ul class="rating-filter-list">
                                            <li><a href="#" class="active">All</a></li>
                                            <li><a href="#">5 sao (8)</a></li>
                                            <li><a href="#">4 sao (12)</a></li>
                                            <li><a href="#">3 sao (23)</a></li>
                                            <li><a href="#">2 sao (10)</a></li>
                                            <li><a href="#">1 sao (0)</a></li>
                                        </ul>
                                    </div>
                                    <div class="add-comment-wrap">
                                        <h5 class="fw-semibold">Add your comment</h5>
                                        <div>
                                            <form class="form-add-comment">
                                                <fieldset class="rate">
                                                    <label>Rating:</label>
                                                    <ul class="list-star justify-content-start">
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star text-main-4"></i>
                                                        </li>
                                                    </ul>
                                                </fieldset>
                                                <fieldset>
                                                    <label>Name:</label>
                                                    <input type="text" placeholder="Your name" required="">
                                                </fieldset>
                                                <fieldset>
                                                    <label>Email:</label>
                                                    <input type="text" placeholder="Your email" required="">
                                                </fieldset>
                                                <fieldset class="align-items-sm-start">
                                                    <label>Comment:</label>
                                                    <textarea placeholder="Message"></textarea>
                                                </fieldset>
                                                <div class="btn-submit">
                                                    <button type="submit" class="tf-btn btn-gray btn-large-2">
                                                        <span class="text-white">Add Review</span>
                                                    </button>
                                                </div>
                                            </form>
                                        </div>
                                    </div>
                                </div>
                                <div class="tab-review-wrap">
                                    <ul class="review-list">
                                        <li class="box-review">
                                            <div class="avt">
                                                <img src="images/avatar/review-1.jpg" alt="">
                                            </div>
                                            <div class="review-content">
                                                <div class="author-wrap">
                                                    <h6 class="name fw-semibold">
                                                        <a href="#" class="link">Cameron Williamson</a>
                                                    </h6>
                                                    <ul class="verified">
                                                        <li class="body-small">Color: Black</li>
                                                        <li class="body-small fw-semibold text-main-2">
                                                            Verified Purchase
                                                        </li>
                                                    </ul>
                                                    <ul class="list-star">
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star text-main-4"></i>
                                                        </li>
                                                    </ul>
                                                </div>
                                                <p class="text-review">
                                                    Bought this nice little electric hot water kettle for an
                                                    overnight
                                                    date. She enjoyed tea and the hotel did not offer tea in the
                                                    room.
                                                    Problem solved! This kettle did its job, through the evening and
                                                    into the morning we enjoyed many cups of nice, loose leaf tea.
                                                    Too
                                                    bad she ended up not liking me and eventually ghosted me. But,
                                                    the
                                                    tea was great thanks to this electric kettle. Highly recommend!
                                                </p>
                                                <p class="date-review body-small">
                                                    14/12/2020 lúc 17:20
                                                </p>
                                            </div>
                                        </li>
                                        <li class="box-review">
                                            <div class="avt">
                                                <img src="images/avatar/review-5.jpg" alt="">
                                            </div>
                                            <div class="review-content">
                                                <div class="author-wrap">
                                                    <h6 class="name fw-semibold">
                                                        <a href="#" class="link">Cameron Williamson</a>
                                                    </h6>
                                                    <ul class="verified">
                                                        <li class="body-small">Color: Black</li>
                                                        <li class="body-small fw-semibold text-main-2">
                                                            Verified Purchase
                                                        </li>
                                                    </ul>
                                                    <ul class="list-star">
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star text-main-4"></i>
                                                        </li>
                                                    </ul>
                                                </div>
                                                <p class="text-review">
                                                    Nullam ornare a magna quis aliquet. Duis suscipit eros in
                                                    suscipit
                                                    venenatis. Pellentesque quis efficitur leo. Maecenas accumsan
                                                    est in
                                                    nibh interdum, quis dignissim neque scelerisque. Ut suscipit et
                                                    leo
                                                    sit amet lacinia. Sed a laoreet leo, ut tristique risus. Integer
                                                    a
                                                    est ut est semper fermentum nec quis nunc. Phasellus aliquam
                                                    neque
                                                    eget quam gravida, quis venenatis turpis tristique. Mauris id
                                                    congue
                                                    augue. Pellentesque hendrerit porttitor purus, vel porttitor sem
                                                    blandit vel.
                                                </p>
                                                <p class="date-review body-small">
                                                    14/12/2020 lúc 17:20
                                                </p>
                                            </div>
                                        </li>
                                        <li class="box-review">
                                            <div class="avt">
                                                <img src="images/avatar/review-6.jpg" alt="">
                                            </div>
                                            <div class="review-content">
                                                <div class="author-wrap">
                                                    <h6 class="name fw-semibold">
                                                        <a href="#" class="link">Cameron Williamson</a>
                                                    </h6>
                                                    <ul class="verified">
                                                        <li class="body-small">Color: Black</li>
                                                        <li class="body-small fw-semibold text-main-2">
                                                            Verified Purchase
                                                        </li>
                                                    </ul>
                                                    <ul class="list-star">
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star"></i>
                                                        </li>
                                                        <li>
                                                            <i class="icon-star text-main-4"></i>
                                                        </li>
                                                    </ul>
                                                </div>
                                                <p class="text-review">
                                                    Suspendisse efficitur velit quis sodales facilisis. Aenean id
                                                    enim
                                                    nec purus interdum semper. In hac habitasse platea dictumst.
                                                    Nulla
                                                    posuere ac ligula sit amet posuere. Curabitur ultricies non dui
                                                    ut
                                                    blandit. In quis nulla nec tellus rutrum porttitor. Sed pharetra
                                                    magna diam, et lacinia tortor congue ut.
                                                </p>
                                                <p class="date-review body-small">
                                                    14/12/2020 lúc 17:20
                                                </p>
                                            </div>
                                        </li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
        <!-- /Product Description Tab -->

        <!-- Discover -->
        <section class="tf-sp-2 pt-0">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Discover Similar Items</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2"
                    data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3"
                    data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                        <!-- item 1 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-99.jpg"
                                            data-src="images/product/product-99.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-91.jpg"
                                            data-src="images/product/product-91.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Samsung Galaxy Note 10+, 256GB, Aura Black - Fully Unlocked
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$24.500</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$31.000</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 2 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-12.jpg"
                                            data-src="images/product/product-12.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-122.jpg"
                                            data-src="images/product/product-122.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smart TVs</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                TCL 32-inch 3-Series 720p Roku Smart TV - 32S335, 2021 Model
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$44.200</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$56.000</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 3 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-10.jpg"
                                            data-src="images/product/product-10.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-109.jpg"
                                            data-src="images/product/product-109.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartwatch</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Garmin fenix 7, adventure smartwatch, rugged outdoor
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$58.200</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$72.800</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 4 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-39.jpg"
                                            data-src="images/product/product-39.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-87.jpg"
                                            data-src="images/product/product-87.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Tracfone Alcatel TCL A3X, 32GB, Prime Black
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$30.300</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$38.500</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 5 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-146.jpg"
                                            data-src="images/product/product-146.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-136.jpg"
                                            data-src="images/product/product-136.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Wireless Earbuds</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Skullcandy 2XL Spoke 2.0 In-Ear Earbuds - Black
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$65.000</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$81.000</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 6 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-99.jpg"
                                            data-src="images/product/product-99.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-91.jpg"
                                            data-src="images/product/product-91.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Samsung Galaxy Note 10+, 256GB, Aura Black - Fully Unlocked
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$15.600</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$20.100</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center">
                    </div>
                </div>
            </div>
        </section>
        <!-- /Discover -->
        <!-- Related -->
        <section class="tf-sp-2 pt-0">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Products Related To This Item</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2"
                    data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3"
                    data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                        <!-- item 1 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-57.jpg"
                                            data-src="images/product/product-57.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-21.jpg"
                                            data-src="images/product/product-21.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Game Controller</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                PowerA Enhanced Wired Controller for Xbox Series X|S - white
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$49.500</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$62.500</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 2 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-20.jpg"
                                            data-src="images/product/product-20.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-75.jpg"
                                            data-src="images/product/product-75.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Headphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                TCL 32-inch 3-Series 720p Roku Smart TV - 32S335, 2021 Model
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$58.000</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$72.300</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 3 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-19.jpg"
                                            data-src="images/product/product-19.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-89.jpg"
                                            data-src="images/product/product-89.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Laptop & Computer</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                2022 MSI GE76 Raider 17.3" 144 Hz FHD Gaming Laptop 8-Core Intel
                                                i7-11800H
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$34.100</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$41.700</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 4 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-112.jpg"
                                            data-src="images/product/product-112.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-105.jpg"
                                            data-src="images/product/product-105.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                GameConsole Destiny Special Edition
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$55.200</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$69.200</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 5 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-124.jpg"
                                            data-src="images/product/product-124.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-148.jpg"
                                            data-src="images/product/product-148.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Laptop & Computer</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Newest HP 14" HD Laptop, Windows 11
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$31.200</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$24.400</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 6 -->
                        <div class="swiper-slide">
                            <div class="card-product">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-99.jpg"
                                            data-src="images/product/product-99.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-91.jpg"
                                            data-src="images/product/product-91.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Samsung Galaxy Note 10+, 256GB, Aura Black - Fully Unlocked
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium mb-0">$43.900</span>
                                            <span class="old-price body-md-2 text-main-2 fw-normal">$55.700</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center">
                    </div>
                </div>
            </div>
        </section>
        <!-- /Related -->
        <!-- Brand -->
        <div class="themesFlat">
            <div class="container">
                <div class="line-bt line-tp">
                    <div class="infiniteslide tf-brand ">
                        <div class="brand-item">
                            <img src="images/brand/lead-ecommerce.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/global-brand.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/great-deal.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/walmart.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/rodem.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/fabric.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/sudo.svg" alt="brand">
                        </div>
                        <div class="brand-item">
                            <img src="images/brand/ctaecom.svg" alt="brand">
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <!-- /Brand -->
        <!-- Recently -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Recently Viewed</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2"
                    data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3"
                    data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                        <!-- item 1 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0s">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-134.jpg"
                                            data-src="images/product/product-134.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-detail-12.jpg"
                                            data-src="images/product/product-detail-12.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Headphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Urbanears Pampas – Wireless Over-Ear Headphones with Immersive Sound
                                                (Almond Beige)
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$48.990</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 2 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0.1s">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-2.jpg"
                                            data-src="images/product/product-2.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-detail-9.jpg"
                                            data-src="images/product/product-detail-9.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Headphone</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Upgrader Headphones – Altec Lansing by ECCO Design, Premium Sound &
                                                Comfort
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$27.500</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 3 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0.2s">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-3.jpg"
                                            data-src="images/product/product-3.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-10.jpg"
                                            data-src="images/product/product-10.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Smartwatch</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Apple Watch Series 6 (GPS) – 40mm Aluminum Case with Sport Band,
                                                Official Warranty
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$63.999</span>
                                        </p>
                                    </div>

                                </div>
                            </div>
                        </div>
                        <!-- item 4 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0.3s">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-4.jpg"
                                            data-src="images/product/product-4.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-19.jpg"
                                            data-src="images/product/product-19.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Laptop & Computer</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                Lenovo Yoga 910-13IKB – 2-in-1 Ultrabook with Touchscreen & 360° Hinge
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$39.990</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 5 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0.4s">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-5.jpg"
                                            data-src="images/product/product-5.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-153.jpg"
                                            data-src="images/product/product-153.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Wireless Earphones</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                JBL LIVE200BT – Wireless Neckband Earphones with Premium Sound & Comfort
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$14.999</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 6 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-6.jpg"
                                            data-src="images/product/product-6.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-43.jpg"
                                            data-src="images/product/product-43.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Electronics</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                SteelSeries Aerox 9 Wireless – Ultra-Lightweight Gaming Mouse with 12
                                                Programmable Buttons
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$87.500</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- item 7 -->
                        <div class="swiper-slide">
                            <div class="card-product style-img-border">
                                <div class="card-product-wrapper">
                                    <a href="product-detail.html" class="product-img">
                                        <img class="img-product lazyload" src="images/product/product-7.jpg"
                                            data-src="images/product/product-7.jpg" alt="image-product">
                                        <img class="img-hover lazyload" src="images/product/product-7.jpg"
                                            data-src="images/product/product-7.jpg" alt="image-product">
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href="#shoppingCart" data-bs-toggle="offcanvas"
                                                class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Add to Cart</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href="#;" class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Add to Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal"
                                                class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Quick View</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas"
                                                class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Compare</span>
                                            </a>
                                        </li>
                                    </ul>
                                </div>
                                <div class="card-product-info">
                                    <div class="box-title">
                                        <div class="d-flex flex-column">
                                            <p class="caption text-main-2 font-2">Wired Earphones</p>
                                            <a href="product-detail.html"
                                                class="name-product body-md-2 fw-semibold text-secondary link">
                                                3.5mm Stereo Earphones – HiFi Bass Headphones with Microphone for Music
                                                & Calls
                                            </a>
                                        </div>
                                        <p class="price-wrap fw-medium">
                                            <span class="new-price price-text fw-medium">$74.600</span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                </div>
            </div>
        </section>
        <!-- /Recently -->

        <!-- Iconbox -->
        <div class="tf-sp-2 pt-0">
            <div class="container">
                <div class="swiper tf-sw-iconbox" data-preview="5" data-tablet="3.5" data-mobile-sm="2.5"
                    data-mobile="1" data-space-lg="20" data-space-md="20" data-space="15" data-pagination="1"
                    data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="4">
                    <div class="swiper-wrapper">
                        <div class="swiper-slide">
                            <div class="tf-icon-box">
                                <div class="icon-box">
                                    <i class="icon icon-delivery"></i>
                                </div>
                                <div class="content">
                                    <p class="body-text fw-semibold">Free delivery</p>
                                    <p class="body-text-3">Velit ullamco elit et aliqua magna</p>
                                </div>
                            </div>
                        </div>
                        <div class="swiper-slide">
                            <div class="tf-icon-box">
                                <div class="icon-box">
                                    <i class="icon icon-check-2"></i>
                                </div>
                                <div class="content">
                                    <p class="body-text fw-semibold">Support 24/7</p>
                                    <p class="body-text-3">Velit ullamco elit et aliqua magna</p>
                                </div>
                            </div>
                        </div>
                        <div class="swiper-slide">
                            <div class="tf-icon-box">
                                <div class="icon-box">
                                    <i class="icon icon-money-bag"></i>
                                </div>
                                <div class="content">
                                    <p class="body-text fw-semibold">Payment</p>
                                    <p class="body-text-3">Velit ullamco elit et aliqua magna</p>
                                </div>
                            </div>
                        </div>
                        <div class="swiper-slide">
                            <div class="tf-icon-box">
                                <div class="icon-box">
                                    <i class="icon icon-shield"></i>
                                </div>
                                <div class="content">
                                    <p class="body-text fw-semibold">Reliable</p>
                                    <p class="body-text-3">Velit ullamco elit et aliqua magna</p>
                                </div>
                            </div>
                        </div>
                        <div class="swiper-slide">
                            <div class="tf-icon-box">
                                <div class="icon-box">
                                    <i class="icon icon-accept"></i>
                                </div>
                                <div class="content">
                                    <p class="body-text fw-semibold">Guarantee</p>
                                    <p class="body-text-3">Velit ullamco elit et aliqua magna</p>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="sw-pagination-iconbox sw-dot-default justify-content-center"></div>
                </div>
            </div>
        </div>
        <!-- /Iconbox -->
        <!-- Footer -->
</asp:Content>
<asp:Content ID="cntScripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script type="text/javascript">
        (function() {
            if (typeof window.keepStoreInit === 'function') {
                window.keepStoreInit();
            }
            /* product specific hooks */ if (typeof window.keepStoreProductInit==='function') { window.keepStoreProductInit(); }
        })();
    </script>
</asp:Content>
