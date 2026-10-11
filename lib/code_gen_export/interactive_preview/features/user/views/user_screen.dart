import 'package:flutter/material.dart';
import '../view_models/user_view_model.dart';

import 'package:flutter/services.dart';
import '../../../../../utils/screen_dp.dart';
import '../../../../../utils/design_scale.dart';
import '../../../../../utils/design_frame_widget.dart';
import '../../../../../utils/auto_size_text.dart';
import '../../../../../theme/app_shapes.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../l10n/app_localizations.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late final UserViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = UserViewModel();
    _viewModel.loadData();

  }

  @override
  Widget build(BuildContext context) {
    return DesignScale.using(
      context,
      width: 393,
      height: 759,
      body: () {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: context.appColors.colorFUser,
            statusBarIconBrightness: ThemeData.estimateBrightnessForColor(context.appColors.colorFUser) == Brightness.dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: ThemeData.estimateBrightnessForColor(context.appColors.colorFUser),
            systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: context.appColors.colorFUser,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: DesignScale.current?.contentWidth ?? kMaxContentWidth),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildContainer(context),
                  ),
                    ],
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildContainer(BuildContext context) {
    return ColoredBox(
        color: context.appColors.colorFUser,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;

              return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              SizedBox(
                                  key: Key('f_margin2'),
                                  width: w,
                                  height: 81.hdp,
                                  child: Stack(
                                      children: [
                                          DesignFrameWidget(
                                              key: Key('f_container5'),
                                              height: 46.hdp,
                                              top: 40.hdp,
                                              centerXInParent: true,
                                              stack: [
                                                  DesignFrameWidget(
                                                      key: Key('f_container6'),
                                                      width: 353.wdp,
                                                      left: 20.wdp,
                                                      centerYInParent: true,
                                                      stack: [
                                                          DesignFrameWidget(
                                                              key: Key('tv_demo'),
                                                              width: 77.wdp,
                                                              height: 37.hdp,
                                                              top: 8.hdp,
                                                              centerXInParent: true,
                                                              child: AutoSizeText(
                                                                  text: AppLocalizations.of(context)!.demo16,
                                                                  fontSize: 29.0,
                                                                  alignment: Alignment.center,
                                                                  style: TextStyle(
                                                                      color: context.appColors.colorTextTvDemo,
                                                                      fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                softWrap: true,
                                              ),
                                            )
                                              ],
                                      )
                                      ],
                                )
                                  ],
                        ),
                          ),

                              Padding(
                                  padding: EdgeInsets.only(top: 152.hdp),
                                  child: SizedBox(
                                      key: Key('f_margin'),
                                      width: w,
                                      height: 223.hdp,
                                      child: _buildFMarginContent(context),
                          ),
                              ),

                              SizedBox(
                                  key: Key('f_margin1'),
                                  width: w,
                                  height: 253.hdp,
                                  child: _buildFMargin1Content(context),
                          )
                          ],
                      );
                  },
              ),
          );
      }

      Widget _buildFMarginContent(BuildContext context) {
        return Stack(
            key: Key('f_margin'),
            children: [
              DesignFrameWidget(
                key: Key('f_container'),
                minHeight: 183.hdp,
                wrapContentHeight: true,
                top: 40.hdp,
                centerXInParent: true,
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Padding(
                                padding: EdgeInsets.only(left: 24.wdp),
                                child: SizedBox(
                                    key: Key('f_horizontalborder'),
                                    width: 345.wdp,
                                    height: 61.hdp,
                                    child: Stack(
                                        children: [
                                            DesignFrameWidget(
                                                key: Key('f_container1'),
                                                width: 112.wdp,
                                                height: 20.hdp,
                                                top: 20.hdp,
                                                stack: [
                                                    AutoSizeText(
                                                        key: Key('tv_order_tracking'),
                                                        text: AppLocalizations.of(context)!.orderTracking8,
                                                        fontSize: 16.0,
                                                        alignment: Alignment.centerLeft,
                                                        style: TextStyle(
                                                            color: context.appColors.colorTextTvOrderTracking,
                                        ),
                                        textAlign: TextAlign.start,
                                        softWrap: true,
                                      )
                                        ],
                              )
                                ],
                      ),
                        ),
                            ),

                            Padding(
                                padding: EdgeInsets.only(left: 24.wdp),
                                child: SizedBox(
                                    key: Key('f_horizontalborder1'),
                                    width: 345.wdp,
                                    height: 61.hdp,
                                    child: Stack(
                                        children: [
                                            DesignFrameWidget(
                                                key: Key('f_container2'),
                                                width: 162.wdp,
                                                height: 20.hdp,
                                                top: 20.hdp,
                                                stack: [
                                                    AutoSizeText(
                                                        key: Key('tv_coupon_management'),
                                                        text: AppLocalizations.of(context)!.couponManagement16,
                                                        fontSize: 16.0,
                                                        alignment: Alignment.centerLeft,
                                                        style: TextStyle(
                                                            color: context.appColors.colorTextTvCouponManagement,
                                        ),
                                        textAlign: TextAlign.start,
                                        softWrap: true,
                                      )
                                        ],
                              )
                                ],
                      ),
                        ),
                            ),

                            Padding(
                                padding: EdgeInsets.only(left: 24.wdp),
                                child: SizedBox(
                                    key: Key('f_horizontalborder2'),
                                    width: 345.wdp,
                                    height: 61.hdp,
                                    child: Stack(
                                        children: [
                                            DesignFrameWidget(
                                                key: Key('f_container3'),
                                                width: 131.wdp,
                                                height: 20.hdp,
                                                top: 20.hdp,
                                                stack: [
                                                    AutoSizeText(
                                                        key: Key('tv_product_footprint'),
                                                        text: AppLocalizations.of(context)!.productFootprint16,
                                                        fontSize: 16.0,
                                                        alignment: Alignment.centerLeft,
                                                        style: TextStyle(
                                                            color: context.appColors.colorTextTvProductFootprint,
                                        ),
                                        textAlign: TextAlign.start,
                                        softWrap: true,
                                      )
                                        ],
                              )
                                ],
                      ),
                        ),
                            )
                        ],
                    ),
              )
              ],
          );
      }

      Widget _buildFMargin1Content(BuildContext context) {
        return Stack(
            key: Key('f_margin1'),
            children: [
              DesignFrameWidget(
                key: Key('f_container4'),
                height: 72.hdp,
                top: 181.hdp,
                centerXInParent: true,
                stack: [
                    DesignFrameWidget(
                      key: Key('f_logout_button'),
                      width: 345.wdp,
                      height: 52.hdp,
                      left: 24.wdp,
                      decoration: AppShapes.bgFLogoutButton(context),
                      stack: [
                          DesignFrameWidget(
                            key: Key('tv_logout'),
                            width: 55.wdp,
                            height: 19.hdp,
                            top: 16.hdp,
                            centerXInParent: true,
                            child: AutoSizeText(
                              text: AppLocalizations.of(context)!.logout8,
                              fontSize: 16.0,
                              alignment: Alignment.center,
                              style: TextStyle(
                                color: context.appColors.colorTextTvLogout,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                            ),
                          )
                          ],
                    )
                    ],
              )
              ],
          );
      }

}
