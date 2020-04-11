class ItemEntity {
  String msg;
  int code;
  List<ResultListBean> result;

  ItemEntity({this.msg, this.code, this.result});

  ItemEntity.fromJson(Map<String, dynamic> json) {    
    this.msg = json['msg'];
    this.code = json['code'];
    this.result = (json['result'] as List)!=null?(json['result'] as List).map((i) => ResultListBean.fromJson(i)).toList():null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['msg'] = this.msg;
    data['code'] = this.code;
    data['result'] = this.result != null?this.result.map((i) => i.toJson()).toList():null;
    return data;
  }

}

class ResultListBean {
  String country;
  String temperature;
  String coverImageUrl;
  String address;
  String description;
  String time;
  String mapImageUrl;

  ResultListBean({this.country, this.temperature, this.coverImageUrl, this.address, this.description, this.time, this.mapImageUrl});

  ResultListBean.fromJson(Map<String, dynamic> json) {    
    this.country = json['country'];
    this.temperature = json['temperature'];
    this.coverImageUrl = json['coverImageUrl'];
    this.address = json['address'];
    this.description = json['description'];
    this.time = json['time'];
    this.mapImageUrl = json['mapImageUrl'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['country'] = this.country;
    data['temperature'] = this.temperature;
    data['coverImageUrl'] = this.coverImageUrl;
    data['address'] = this.address;
    data['description'] = this.description;
    data['time'] = this.time;
    data['mapImageUrl'] = this.mapImageUrl;
    return data;
  }
}
