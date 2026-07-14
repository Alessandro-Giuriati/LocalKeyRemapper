//
//  AppCoordinator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//
import AppKit

final class AppCoordinator {

    private var statusBarController: StatusBarController?

    func start() {
        statusBarController = StatusBarController()
    }
}
